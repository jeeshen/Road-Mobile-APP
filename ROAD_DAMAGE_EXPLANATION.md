# How Road Damage Detection Works

## Overview
The road damage detection system uses your phone's **accelerometer** to detect when your car moves up and down, which indicates road damage like potholes, bumps, or uneven surfaces.

## How It Works

### 1. **Accelerometer Monitoring**
- The app continuously monitors the **Z-axis (vertical)** acceleration of your device
- When you hit a pothole or bump, the car moves up/down, causing a sudden change in vertical acceleration
- Normal driving: ~9.8 m/s² (gravity) with small variations
- Road damage: Sudden spikes above 2.5 m/s² threshold

### 2. **Detection Algorithm**
```
1. Collect vertical acceleration readings (last 10 readings)
2. Calculate average of recent 3 readings
3. Compare with previous 3 readings
4. If change > 2.5 m/s² → Road damage detected!
```

### 3. **GPS Integration**
- When damage is detected, the app automatically:
  - Records your current GPS location
  - Shows an alert dialog
  - Offers to create a report immediately

### 4. **Smart Features**
- **Cooldown Period**: Prevents spam (5 seconds between detections)
- **Severity Calculation**: Measures how severe the damage is (0-100%)
- **Automatic Location**: GPS coordinates saved automatically

## Example Flow

```
User driving → Hits pothole → Accelerometer detects spike → 
GPS location captured → Alert shown → User can report → 
Post created with location + "Road Damage" tag
```

## Technical Details

- **Threshold**: 2.5 m/s² (configurable)
- **History Size**: Last 10 acceleration readings
- **GPS Accuracy**: High accuracy, updates every 10 meters
- **Detection Method**: Vertical acceleration change analysis

## When It Works Best

✅ **Works Best:**
- Phone mounted in car (stable position)
- Driving on roads with actual damage
- Consistent phone orientation

⚠️ **May Trigger:**
- Speed bumps (intentional)
- Sharp turns (lateral movement)
- Phone movement (not mounted)

## Privacy & Battery

- **Location**: Only used when damage is detected
- **Battery**: Minimal impact (efficient sensor reading)
- **Data**: Location only saved if user chooses to report


