mod config;
mod controller;
mod message;
mod server;
mod models;
mod serde_timestamp;

use clap::{App, Arg};
use config::{CmdArgs, Configuration};
use log::{debug, error, info, warn, trace};
use log4rs;
use serde_json;
use std::env;
use std::error::Error;
use std::thread;
use tokio::runtime::Builder;

use signal_hook::consts::signal::*;
use signal_hook_tokio::Signals;

use futures::stream::StreamExt;
// wait for merge of log4rs 1.0 support
//use log4rs_syslog;

//trigger rebuild on cargo change, used for clap
//include_str!("../Cargo.toml");

fn parse_args() -> CmdArgs {
    let matches = App::new(clap::crate_name!())
        .version(clap::crate_version!())
        .about(clap::crate_description!())
        .arg(Arg::with_name("verbosity")
             .short("v")
             .long("verbose")
             .help("Sets verbosity level.")
             .long_help("Sets verbosity level. Can be used multiple times to increase log level. Maximum log level is 3.")
             .multiple(true))
        .arg(Arg::with_name("config_file")
             .short("c")
             .long("config")
             .value_name("FILE")
             .help("Sets the path for the config file.")
             .long_help("Sets config file path. If no path is provided, \"ARROW_CONFIG\" environment variable is used. Fallback is \".config/arrow/config\".")
             .takes_value(true))
        .arg(Arg::with_name("log_file")
             .short("l")
             .long("log")
             .value_name("PATH")
             .help("Sets the file log file path.")
             .default_value("/tmp/arrow.log")
             .takes_value(true))
        .get_matches();

    let verbosity = match matches.occurrences_of("verbosity") {
        0 => log::LevelFilter::Warn,
        1 => log::LevelFilter::Info,
        2 => log::LevelFilter::Debug,
        3 | _ => log::LevelFilter::Trace,
    };

    let config_file = match matches.value_of("config_file") {
        Some(f) => Some(f.to_string()),
        _ => None,
    };

    // if no value is provided, default is returned,
    // can therefore never be None
    let log_file = matches.value_of("log_file").unwrap().to_string();

    CmdArgs {
        verbosity,
        config_file,
        log_file,
    }
}

fn configure_logging(
    verbosity: log::LevelFilter,
    file: &str,
) -> Result<log4rs::Handle, log::SetLoggerError> {
    use log4rs::{
        append::{
            console::{ConsoleAppender, Target},
            file::FileAppender,
        },
        config::{Appender, Config, Root},
        encode::pattern::PatternEncoder,
        filter::threshold::ThresholdFilter,
    };

    let encode_color = PatternEncoder::new("[{d(%Y-%m-%d %H:%M:%S)}][{h({l})}] {t} - {m}{n}");
    let encode = PatternEncoder::new("[{d(%Y-%m-%d %H:%M:%S)}][{l}] {t} - {m}{n}");

    // Build a stderr logger.
    let stderr = ConsoleAppender::builder()
        .target(Target::Stderr)
        .encoder(Box::new(encode_color))
        .build();

    // TODO: replace with syslog logger, if available
    let logfile = FileAppender::builder()
        .encoder(Box::new(encode))
        .build(file);

    //build syslog logger
    //let encoder = PatternEncoder::new("{M} - {m}");

    /*let syslog = log4rs_syslog::SyslogAppender::builder()
    .encoder(Box::new(encoder))
    .openlog(
        "log4rs-syslog-arrow",
        log4rs_syslog::LogOption::LOG_PID,
        log4rs_syslog::Facility::Daemon,
    )
    .build();
    */

    let mut config_builder = Config::builder()
        //.appender(Appender::builder().build("syslog", Box::new(syslog)))
        .appender(
            Appender::builder()
                .filter(Box::new(ThresholdFilter::new(verbosity)))
                .build("stderr", Box::new(stderr)),
        );

    let mut root_builder = Root::builder()
        //.appender("syslog")
        .appender("stderr");

    let (file_logfile, err_logfile) = match logfile {
        Ok(l) => (Some(l), None),
        Err(e) => (None, Some(e)),
    };

    if let Some(log) = file_logfile {
        config_builder = config_builder.appender(
            Appender::builder()
                .filter(Box::new(ThresholdFilter::new(log::LevelFilter::Warn)))
                .build("filelog", Box::new(log)),
        );
        root_builder = root_builder.appender("filelog");
    }

    let config = config_builder
        .build(root_builder.build(log::LevelFilter::Trace))
        .unwrap();
    let handle = log4rs::init_config(config);

    if let Some(e) = err_logfile {
        error!(target: "arrow::log", "Error while creating file logger: {}", e);
    }
    handle
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = parse_args();
    configure_logging(args.verbosity, &args.log_file)?;

    let conf_path = args.config_file.unwrap_or_else(|| {
        env::var("ARROW_CONFIG").unwrap_or_else(|_| "~/.config/arrow/config".to_string())
    });

    info!("Trying to read config file from '{}'.", conf_path);
    let config: Configuration = match std::fs::File::open(conf_path) {
        Ok(file) => {
            let reader = std::io::BufReader::new(file);
            serde_json::from_reader(reader).unwrap_or_default()
        }
        Err(e) => {
            warn!("Cannot open config file: '{}'. Using default values.", e);
            Default::default()
        }
    };
    debug!("Using config {:#?}", config);

    let web_rt = Builder::new_multi_thread()
        .enable_io()
        .enable_time()
        .thread_name("arrow-web-tokio-worker")
        .build()?;

    let hardware_rt = Builder::new_multi_thread()
        .enable_io()
        .enable_time()
        .thread_name("arrow-hw-tokio-worker")
        .build()?;

    let (srv_handle, server) = web_rt.block_on(server::new(&config))?;
    let mut ctl = controller::Controller::new(server.clone())?;
    let ctl_sender = ctl.ctl_tx.clone();
    let hw_thread = thread::spawn(move || {
        hardware_rt.block_on(ctl.start());
    });

    //TODO: gracefully shut down hardware
    let _ = web_rt.block_on(async move {
        let signals = Signals::new(&[SIGHUP, SIGTERM, SIGINT, SIGQUIT])?;
        let handle = signals.handle();

        let _signals_task = tokio::spawn(async move {
            let mut signals = signals.fuse();
            while let Some(signal) = signals.next().await {
                match signal {
                    SIGHUP => {
                        // Reload configuration
                        // Reopen the log file
                    }
                    SIGTERM | SIGINT | SIGQUIT => {
                        println!("\rReceived shutdown Signal. Shutting down.");
                        let _ = ctl_sender.send(message::ControlMessage::Terminate).await;
                        if let Err(e) = server.shutdown_tx.send(()).await {
                            error!("Error while shutting down: '{}'. Aborting.", e);
                            panic!("Aborted due to error while shutting down.");
                        }
                    }
                    _ => unreachable!(),
                }
            }
        });
        srv_handle.bind(([127, 0, 0, 1], 8000))?.1.await;

        handle.close();
        // Rust type inference helper
        Ok::<(), Box<dyn Error>>(())
    });

    trace!("waiting to join hardware thread.");
    hw_thread.join().unwrap();
    Ok(())
}
