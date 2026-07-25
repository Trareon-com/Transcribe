//! Audio device enumeration via cpal.

use cpal::traits::{DeviceTrait, HostTrait};
use serde::Serialize;

use crate::error::TrascribeError;

#[derive(Debug, Clone, Serialize)]
pub struct AudioDeviceInfo {
    pub name: String,
    pub device_id: String,
    pub is_default: bool,
    pub channels: u16,
    pub sample_rates: Vec<u32>,
}

pub fn list_input_devices() -> Result<Vec<AudioDeviceInfo>, TrascribeError> {
    let host = cpal::default_host();
    let default_name = host.default_input_device().and_then(|d| d.name().ok());

    let devices = host
        .input_devices()
        .map_err(|e| TrascribeError::AudioDevice(e.to_string()))?;

    let mut out = Vec::new();
    for device in devices {
        let name = device
            .name()
            .map_err(|e| TrascribeError::AudioDevice(e.to_string()))?;
        let is_default = default_name.as_deref() == Some(name.as_str());

        let (channels, sample_rates) = match device.supported_input_configs() {
            Ok(configs) => {
                let configs: Vec<_> = configs.collect();
                let channels = configs.first().map(|c| c.channels()).unwrap_or(1);
                let rates = configs
                    .iter()
                    .map(|c| c.min_sample_rate().0)
                    .collect::<Vec<_>>();
                (channels, rates)
            }
            Err(_) => (1, vec![]),
        };

        out.push(AudioDeviceInfo {
            name,
            device_id: format!("input:{}", out.len()),
            is_default,
            channels,
            sample_rates,
        });
    }
    Ok(out)
}

/// Best-effort lookup for a macOS/Windows loopback device by name convention
/// (BlackHole on macOS, WASAPI loopback exposed as an input-capable output
/// device on Windows). Returns an error the caller should surface as
/// "install BlackHole" / wizard guidance rather than a crash.
pub fn get_loopback_device(name_hint: &str) -> Result<AudioDeviceInfo, TrascribeError> {
    let devices = list_input_devices()?;
    devices
        .into_iter()
        .find(|d| d.name.to_lowercase().contains(&name_hint.to_lowercase()))
        .ok_or_else(|| {
            TrascribeError::AudioDevice(format!("no loopback device matching '{name_hint}' found"))
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn list_input_devices_does_not_error() {
        // CI runners may have zero audio devices; this must not panic or
        // error out just because the list is empty.
        let result = list_input_devices();
        assert!(result.is_ok());
    }

    #[test]
    fn missing_loopback_device_returns_error_not_panic() {
        let result = get_loopback_device("definitely-not-a-real-device-xyz123");
        assert!(result.is_err());
    }
}
