use rust_core::audio::device::{list_input_devices, list_output_devices};

fn main() {
    let inputs = list_input_devices().expect("list_input_devices failed");
    println!("Input devices ({}):", inputs.len());
    for d in &inputs {
        println!(
            "  name={:?} id={:?} default={} channels={} sample_rates={:?}",
            d.name, d.device_id, d.is_default, d.channels, d.sample_rates
        );
    }

    let outputs = list_output_devices().expect("list_output_devices failed");
    println!("Output devices ({}):", outputs.len());
    for d in &outputs {
        println!(
            "  name={:?} id={:?} default={} channels={} sample_rates={:?}",
            d.name, d.device_id, d.is_default, d.channels, d.sample_rates
        );
    }
}
