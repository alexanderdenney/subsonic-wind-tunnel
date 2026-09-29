/*
 * @file arduinoSoftware.cpp
 * @author Alexander Denney
 * @version 1.1
 * 
 * MPXV7002DP & Arduino Uno R3 Airspeed Telemetry for the wind tunnel
 *
 */

const int SENSOR_PIN = A0;

const float AIR_DENSITY = 1.225;  // kg/m^3 (standard)

const int numReadings = 50;      // moving average, 50-point buffer for signal smoothing
int readings[numReadings];      
int readIndex = 0;              
long total = 0;                  

float zeroOffsetVoltage = 2.5;   // default theoretical center

void setup() {
  Serial.begin(9600); // Noted after running the experiment: 9600 baud bottlenecks the loop time to ~24Hz, I will use 115200 baud in the future
  
  for (int i = 0; i < numReadings; i++) { // smoothing array
    readings[i] = 0;
  }
  
  // zeroing out prior to recording data
  Serial.println("Calibrating zero point... KEEP FAN OFF.");
  long initTotal = 0;
  for(int i = 0; i < 100; i++) {
    initTotal += analogRead(SENSOR_PIN);
    delay(10);
  }
  
  float initialAverageRaw = initTotal / 100.0;
  zeroOffsetVoltage = (initialAverageRaw / 1023.0) * 5.0;
  
  Serial.print("Zero Offset Voltage Locked: ");
  Serial.print(zeroOffsetVoltage, 4);
  Serial.println(" V");
  Serial.println("Calibration complete. Spool up the tunnel.");
  delay(3000);
}

void loop() {
  total = total - readings[readIndex];
  readings[readIndex] = analogRead(SENSOR_PIN);
  total = total + readings[readIndex];
  readIndex = readIndex + 1;

  if (readIndex >= numReadings) {
    readIndex = 0;
  }

  float avgRaw = (float)total / numReadings;
  float voltage = (avgRaw / 1023.0) * 5.0;

  // MPXV7002DP scales at 1V per 1 kPa when operated @ 5V
  float deltaPressure = (voltage - zeroOffsetVoltage) * 1000.0; // Differential pressure

  if (deltaPressure < 0) { // guard sqrt function
    deltaPressure = 0.0;
  }

  // Bernoulli's Incompressible Flow (Note theoretical airspeed of wind tunnel is ~16 m/s, well below M = 0.3)
  float velocity = sqrt((2.0 * deltaPressure) / AIR_DENSITY);

  // output -> "Serial Monitor"
  Serial.print("Pressure(Pa):");
  Serial.print(deltaPressure);
  Serial.print("\t");
  Serial.print("Velocity(m/s):");
  Serial.println(velocity);

  delay(20); // 50 Hz
}