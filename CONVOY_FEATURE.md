# Drive Party / Convoy Feature Documentation

## Overview

The Drive Party (Convoy) feature enables groups of friends to coordinate road trips together with real-time location sharing, status updates, smart alerts, and built-in chat functionality.

## Features Implemented

### 1. **Create & Manage Trips** ✅
- Create a new convoy trip with:
  - Trip title and description
  - Start location (auto-detected from current position)
  - Destination with coordinates
  - Estimated arrival time
  - Location update interval (10s, 30s, or 1min)
- Trip lifecycle management (Planned → Active → Completed/Cancelled)
- Trip creator controls (start trip, complete trip)

### 2. **Friend Invitations** ✅
- Invite friends from your friend list to join convoy
- Friends receive real-time invitations
- Accept/Decline invitation flow
- Multiple friends can join the same convoy
- Participants list with status tracking

### 3. **Real-time Location Sharing** ✅
- Automatic location updates based on trip interval setting
- Live map view showing all participants' positions
- Animated markers with participant names
- Route visualization on map
- Destination marker with flag icon
- Location updates only when trip is active

### 4. **Auto Status Broadcast** ✅
- Quick status updates with predefined types:
  - 🅿 Rest Stop
  - 🚻 Toilet Break
  - ⛽ Fuel Stop
  - 🍔 Food Break
  - ⚠️ Having Issues
  - 🚙 Resume Trip
- System broadcasts status to all convoy members
- Status history view with timestamps
- Manual status posting via action sheet

### 5. **Smart Alerts** ✅
- **No Movement Detection**: Alerts if user hasn't moved for 10+ minutes
- **Destination Arrival**: Automatic detection when user reaches destination (100m threshold)
- **Safety Check Dialog**: Prompts user if no movement detected
- **Emergency Alerts**: Can send SOS to convoy members
- Real-time notifications for all participants
- System-generated alerts for convoy events

### 6. **Trip Chat** ✅
- Dedicated group chat for convoy
- Message types supported:
  - Text messages
  - Location sharing
  - Photo sharing (camera)
  - Voice messages (future enhancement)
- Real-time message streaming
- System alerts integrated into chat
- Modern chat bubble UI
- Message timestamps
- Auto-scroll to latest messages

### 7. **Safety Mode** ✅
- Continuous monitoring of participant activity
- Automatic detection of:
  - No movement for extended period (10+ minutes)
  - Location not updating
- Alert options:
  - "I'm OK" - resets safety timer
  - "Need Help" - sends emergency alert to convoy
- Emergency broadcast to all participants with location

### 8. **End Trip & Statistics** ✅
- Manual trip completion by creator
- Auto-completion options
- Trip statistics recorded:
  - Total distance traveled
  - Trip duration
  - Number of participants
  - Number of status updates
  - Rest stops count
- Trip history view
- Completed trips archive

## User Interface

### iOS Theme Consistency ✅
All screens follow iOS design guidelines using Cupertino widgets:
- **Navigation Bars**: Standard iOS navigation with back buttons
- **Segmented Controls**: For tab switching (Active/Invites/History, Map/Status/Chat)
- **Action Sheets**: For status selection and actions
- **Alert Dialogs**: For confirmations and errors
- **List Tiles**: iOS-style list items with icons
- **Color Scheme**: System colors (systemBlue, systemGreen, systemRed, etc.)
- **Typography**: SF Pro font family (default iOS)
- **Shadows & Borders**: Subtle iOS-style shadows
- **Cards**: Rounded corners (12-16px radius)

### Screen Flow
```
Home Screen (Purple Car Button)
    ↓
Convoy List Screen
    ├── Active Trips Tab
    ├── Invitations Tab
    └── History Tab
    ↓
Create Trip Screen (+ Button)
    ├── Trip Details
    ├── Destination
    ├── Settings
    └── Invite Friends
    ↓
Trip Detail Screen
    ├── Map View (with all participants)
    ├── Status Updates View
    └── Chat View
```

## Technical Implementation

### Models
1. **Trip** (`lib/models/trip.dart`)
   - Trip metadata, route, participants, status
   - Lifecycle states: planned, active, completed, cancelled

2. **TripParticipant** (`lib/models/trip.dart`)
   - User info, role (creator/member)
   - Status: pending, active, declined, left
   - Current location and last update time

3. **TripStatusUpdate** (`lib/models/trip_status_update.dart`)
   - Status type with emoji
   - Location and timestamp
   - Auto-detected vs manual flag

4. **TripMessage** (`lib/models/trip_message.dart`)
   - Message types: text, location, photo, voice, system
   - Sender info, content, timestamp

### Services
**ConvoyService** (`lib/services/convoy_service.dart`)
- Trip CRUD operations
- Invitation management
- Real-time location updates
- Status broadcasting
- Chat messaging
- Safety monitoring utilities
- Distance calculations
- Route validation

### Screens
1. **ConvoyListScreen** (`lib/screens/convoy_list_screen.dart`)
   - List active trips
   - Show pending invitations
   - View trip history
   - Create new trip button

2. **CreateTripScreen** (`lib/screens/create_trip_screen.dart`)
   - Trip configuration form
   - Friend selection
   - Date/time picker
   - Update interval settings

3. **TripDetailScreen** (`lib/screens/trip_detail_screen.dart`)
   - Real-time map with participants
   - Status updates feed
   - Group chat
   - Safety monitoring
   - Trip controls

## Firebase Collections

### Database Structure
```
convoy_trips/
  {tripId}/
    - id, title, creatorId, creatorName
    - startLocation, destination, route
    - participants (array)
    - status, timestamps
    - stats

trip_status_updates/
  {statusId}/
    - tripId, userId, userName
    - type, location, timestamp
    - isAutoDetected

trip_messages/
  {messageId}/
    - tripId, senderId, senderName
    - type, content, location
    - timestamp, isRead

trip_invitations/
  {invitationId}/
    - tripId, inviterId, inviteeId
    - status, timestamps
```

## Usage Instructions

### For Trip Creator:
1. Tap the purple car icon on home screen
2. Tap the "+" button to create new trip
3. Enter trip details and destination coordinates
4. Select update interval (10s/30s/1min)
5. Optionally invite friends
6. Tap "Create" to create the trip
7. When ready, tap "Start" to begin the convoy
8. Share status updates during the trip
9. Chat with participants
10. Tap "Complete" when everyone reaches destination

### For Participants:
1. Open app and check the purple car icon
2. Go to "Invites" tab
3. Accept or decline invitations
4. Once accepted, trip appears in "Active" tab
5. Tap trip to view details and join convoy
6. Real-time location sharing starts automatically
7. Post status updates as needed
8. Use chat to communicate
9. System will alert if you stop moving for too long

## Safety Features

### Automatic Monitoring
- Location tracking every X seconds (based on trip settings)
- Movement detection algorithm
- 10-minute no-movement threshold
- Automatic safety check prompts

### Emergency Response
- One-tap emergency alert
- Broadcasts location to all participants
- Visible in chat and status feed
- Can trigger from safety dialog or manual status

### Privacy
- Location sharing ONLY active during convoy
- Can leave trip at any time
- Data retained only for active trips
- Completed trips stored for statistics

## Future Enhancements (Optional)

### Potential Features
- [ ] Voice message recording
- [ ] Turn-by-turn navigation integration
- [ ] Automatic route deviation alerts
- [ ] Fuel station finder
- [ ] Rest area recommendations
- [ ] Speed monitoring and alerts
- [ ] Weather alerts along route
- [ ] Offline mode support
- [ ] Share trip link with non-users
- [ ] Export trip summary PDF

## Troubleshooting

### Common Issues

**Location not updating**
- Ensure location permissions are granted
- Check GPS is enabled on device
- Verify network connectivity

**Can't create trip**
- Make sure location services are enabled
- Enter valid destination coordinates
- Latitude range: -90 to 90
- Longitude range: -180 to 180

**Friends not receiving invitations**
- Check internet connection
- Verify friend is in your friends list
- Try re-sending invitation

**Chat messages not sending**
- Check network connectivity
- Verify trip is active
- Reload the screen

## Performance Considerations

- Location updates are throttled based on trip settings
- Firebase listeners are properly disposed
- Map markers are optimized for multiple participants
- Message history limited to last 100 messages
- Status updates limited to last 50 updates

## Security Notes

- Trip data is stored in Firestore with proper access rules
- Only participants can view trip details
- Invitations can only be sent to friends
- Trip creator has admin controls
- Location data is only shared during active trips

---

**Built with Flutter & Firebase**
**iOS Design Guidelines Compliant**
**Real-time Synchronization**



