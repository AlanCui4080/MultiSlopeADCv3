import serial
import struct
import numpy as np
from scipy import stats

# Open serial port
ser = serial.Serial('COM17', 115200, timeout=1)

# Initialize lists to store data
input_voltages = np.arange(-9, 10)  # -9 to 9
measured_values = []

try:
    # Read data for each input voltage
    for voltage in input_voltages:
        # Read exactly 8 bytes (4 bytes pos + 4 bytes neg), block until complete
        data = ser.read(12)
        while len(data) < 12:
            data += ser.read(12 - len(data))
        
        # Unpack binary data
        total = struct.unpack('I', data[:4])[0]  # First 4 bytes
        neg = struct.unpack('I', data[4:8])[0]  # Middle 4 bytes
        pos = struct.unpack('I', data[8:])[0]  # Last 4 bytes
        
        # Calculate actual value
        value = (pos - neg) / total * 10
        measured_values.append(value)
        print(f"Raw data for input {voltage}V: pos={pos}, neg={neg}, total={total}")
        print(f"Measured voltage for input {voltage}V: {value:.6f}V")


finally:
    ser.close()

# Convert to numpy array
measured_values = np.array(measured_values)
# Calculate INL for -9V to +9V range
slope_9v, intercept_9v, _, _, _ = stats.linregress(input_voltages, measured_values)
best_fit_9v = slope_9v * input_voltages + intercept_9v
inl_9v = measured_values - best_fit_9v

# Calculate INL for -5V to +5V range
mask_5v = (input_voltages >= -5) & (input_voltages <= 5)
slope_5v, intercept_5v, _, _, _ = stats.linregress(input_voltages[mask_5v], measured_values[mask_5v])
best_fit_5v = slope_5v * input_voltages + intercept_5v
inl_5v = measured_values[mask_5v] - best_fit_5v[mask_5v]

print(f"\nFit parameters for -9V to +9V range:")
print(f"Slope: {slope_9v:.6f}")
print(f"Intercept: {intercept_9v:.6f}")

print(f"\nFit parameters for -5V to +5V range:")
print(f"Slope: {slope_5v:.6f}")
print(f"Intercept: {intercept_5v:.6f}")
print("INL values for each input voltage:")

# for voltage, inl_value in zip(input_voltages, inl):
#     print(f"Input: {voltage:2d}V, INL: {inl_value/20*100:.6f}%")

print(f"Max INL (-9V to +9V): {np.max(np.abs(inl_9v))/20*100:.6f}%")
print(f"Max INL (-5V to +5V): {np.max(np.abs(inl_5v))/20*100:.6f}%")

# Plot the results
import matplotlib.pyplot as plt

plt.figure(figsize=(10, 6))
plt.plot(input_voltages, measured_values, 'bo-', label='Measured Values')
plt.plot(input_voltages, best_fit_9v, 'r--', label='Best Fit Line 9V')
plt.plot(input_voltages, best_fit_5v, 'g--', label='Best Fit Line 5V')
plt.grid(True)
plt.xlabel('Input Voltage (V)')
plt.ylabel('Measured Voltage (V)')
plt.title('ADC Transfer Function')
plt.legend()
plt.show()