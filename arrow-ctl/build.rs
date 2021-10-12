use fs_extra::dir;
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::Path;
use std::path::PathBuf;
use std::process::Command;

fn get_frontend_path() -> PathBuf {
    //<root or manifest path>/target/<profile>/
    //let manifest_dir_string = env::var("CARGO_MANIFEST_DIR").unwrap();
    let out_dir = env::var("OUT_DIR").unwrap();
    let _path = Path::new(&out_dir).join("../../../");
    /*let build_type = env::var("PROFILE").unwrap();
    let path = Path::new(&manifest_dir_string)
        .join("target")
        .join(build_type);
    */
    let static_path = Path::join(&env::current_dir().unwrap(), "static");
    return static_path;
    //return PathBuf::from(path).join("frontend");
}

fn main() {
    let _out_dir = env::var_os("OUT_DIR").unwrap();
    let frontend_path = get_frontend_path();
    let main_dest_path = frontend_path.clone().join("main.js");
    fs::create_dir_all(Path::join(&frontend_path, "css")).unwrap(); //exit if directory cannot be created
    let in_path = Path::join(&env::current_dir().unwrap(), "frontend/src/Main.elm");
    let elm_working_dir = Path::join(&env::current_dir().unwrap(), "frontend");
    let output = Command::new("elm")
        .current_dir(elm_working_dir)
        .arg("make")
        .arg(format!("--output={}", main_dest_path.to_str().unwrap()))
        .arg(in_path.to_str().unwrap())
        .output()
        .expect("could not start elm compiler");
    if !output.status.success() {
        io::stderr().write_all(&output.stderr).unwrap();
        panic!("could not compile elm program");
    }
    let copy_options = dir::CopyOptions {
        overwrite: true,
        copy_inside: true,
        ..dir::CopyOptions::new()
    };
    let static_src = vec![
        Path::join(&env::current_dir().unwrap(), "frontend/css"),
        Path::join(&env::current_dir().unwrap(), "frontend/webfonts"),
        Path::join(&env::current_dir().unwrap(), "frontend/translations"),
        Path::join(&env::current_dir().unwrap(), "frontend/images"),
    ];
    fs_extra::copy_items(&static_src, &frontend_path, &copy_options).unwrap();
    fs::copy(
        Path::join(&env::current_dir().unwrap(), "frontend/arrow.html"),
        Path::join(&frontend_path, "arrow.html"),
    )
    .unwrap();
    println!("cargo:rerun-if-changed=frontend");
    println!("cargo:rerun-if-changed=build.rs");
}
