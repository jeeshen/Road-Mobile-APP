import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show TabController, TabBarView;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user.dart';
import '../models/trip.dart';
import '../services/convoy_service.dart';
import 'navigation_screen.dart';

class ConvoyListScreen extends StatefulWidget {
  final User currentUser;

  const ConvoyListScreen({super.key, required this.currentUser});

  @override
  State<ConvoyListScreen> createState() => _ConvoyListScreenState();
}

class _ConvoyListScreenState extends State<ConvoyListScreen>
    with SingleTickerProviderStateMixin {
  final ConvoyService _convoyService = ConvoyService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateInfo() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Create Drive Party'),
        content: const Text(
          'To create a drive party:\n\n'
          '1. Tap the navigation button on the home screen\n'
          '2. Enter your destination\n'
          '3. Select "Create Drive Party" when starting navigation\n'
          '4. Invite friends to join your convoy',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Got it'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToTrip(Trip trip) async {
    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      if (!mounted) return;

      // Navigate to navigation screen with existing trip (skip route planning)
      Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => NavigationScreen(
            destination: trip.destination,
            destinationName: trip.destinationAddress,
            currentPosition: position,
            allPosts: const [], // Empty for now, can be populated later
            districts: const [], // Empty for now, can be populated later
            existingTrip: trip, // Pass the trip to skip route planning
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text('Failed to start navigation: $e'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  void _showTripInfo(Trip trip) {
    final activeParticipants = trip.participants
        .where((p) => p.status == ParticipantStatus.active)
        .length;
    final isActive = trip.status == TripStatus.active;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(trip.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text('Creator: ${trip.creatorName}'),
            Text('Participants: $activeParticipants'),
            Text('Status: ${trip.status.name}'),
            if (isActive) ...[
              const SizedBox(height: 8),
              const Text(
                'This trip is currently active. Join navigation to chat and track progress.',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
          if (isActive)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(context);
                _navigateToTrip(trip);
              },
              child: const Text('Join Navigation'),
            ),
        ],
      ),
    );
  }

  Future<void> _handleInvitationAction(
    Map<String, dynamic> invitation,
    bool accept,
  ) async {
    final invitationData = invitation['invitation'] as Map<String, dynamic>;
    final invitationId = invitationData['id'] as String;
    final tripData = invitation['trip'] as Map<String, dynamic>;
    final tripId = tripData['id'] as String;
    final trip = Trip.fromMap(tripData);

    try {
      if (accept) {
        await _convoyService.acceptTripInvitation(
          invitationId: invitationId,
          tripId: tripId,
          userId: widget.currentUser.id,
          userName: widget.currentUser.name,
        );
        if (mounted) {
          // Show success and navigate to trip
          showCupertinoDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Invitation Accepted'),
              content: const Text('You have joined the convoy! Starting navigation...'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Go Now'),
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToTrip(trip);
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Later'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      } else {
        await _convoyService.declineTripInvitation(invitationId);
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildTripCard(Trip trip) {
    final isActive = trip.status == TripStatus.active;
    final isCreator = trip.creatorId == widget.currentUser.id;
    final activeParticipants = trip.participants
        .where((p) => p.status == ParticipantStatus.active)
        .length;

    return GestureDetector(
      onTap: () => _showTripInfo(trip),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: CupertinoColors.systemGreen, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                        : CupertinoColors.systemBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive
                        ? CupertinoIcons.car_detailed
                        : CupertinoIcons.map_fill,
                    color: isActive
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.systemBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${trip.creatorName}${isCreator ? ' (You)' : ''}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRouteInfo(
              icon: CupertinoIcons.location,
              label: 'From',
              text: trip.startAddress,
            ),
            const SizedBox(height: 8),
            _buildRouteInfo(
              icon: CupertinoIcons.location_fill,
              label: 'To',
              text: trip.destinationAddress,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  icon: CupertinoIcons.person_2_fill,
                  text: '$activeParticipants',
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: CupertinoIcons.time,
                  text: DateFormat('MMM d, HH:mm').format(trip.estimatedArrival),
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: CupertinoIcons.arrow_merge,
                  text: '${(trip.totalDistance / 1000).toStringAsFixed(1)} km',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo({
    required IconData icon,
    required String label,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CupertinoColors.systemGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: CupertinoColors.systemGrey),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> invitation) {
    final tripData = invitation['trip'] as Map<String, dynamic>;
    final trip = Trip.fromMap(tripData);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with notification badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CupertinoColors.systemOrange.withValues(alpha: 0.15),
                  CupertinoColors.systemOrange.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemOrange.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.bell_fill,
                    color: CupertinoColors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip Invitation',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.systemOrange,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.creatorName} invited you to join this convoy',
                  style: const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.label,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildRouteInfo(
                        icon: CupertinoIcons.arrow_up_circle_fill,
                        label: 'From',
                        text: trip.startAddress,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Container(
                              width: 2,
                              height: 20,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    CupertinoColors.systemGrey.withValues(alpha: 0.3),
                                    CupertinoColors.systemGrey.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildRouteInfo(
                        icon: CupertinoIcons.location_solid,
                        label: 'To',
                        text: trip.destinationAddress,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    borderRadius: BorderRadius.circular(14),
                    color: CupertinoColors.systemGrey5,
                    onPressed: () => _handleInvitationAction(invitation, false),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: CupertinoColors.label,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    borderRadius: BorderRadius.circular(14),
                    color: CupertinoColors.systemGreen,
                    onPressed: () => _handleInvitationAction(invitation, true),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Drive Party'),
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showCreateInfo,
          child: const Icon(CupertinoIcons.info_circle),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _tabController.index,
                backgroundColor: CupertinoColors.systemGrey6,
                thumbColor: CupertinoColors.systemBackground,
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _tabController.animateTo(value);
                    });
                  }
                },
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Active'),
                  ),
                  1: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('Invites'),
                  ),
                  2: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text('History'),
                  ),
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Trips Tab
                  StreamBuilder<List<Trip>>(
                    stream: _convoyService
                        .getUserActiveTrips(widget.currentUser.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final trips = snapshot.data ?? [];

                      if (trips.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.car_detailed,
                                  size: 64,
                                  color: CupertinoColors.systemGrey3,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No Active Drive Parties',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                CupertinoButton.filled(
                                  onPressed: _showCreateInfo,
                                  child: const Text('How to Create'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          return _buildTripCard(trips[index]);
                        },
                      );
                    },
                  ),

                  // Invitations Tab
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _convoyService
                        .getPendingInvitations(widget.currentUser.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final invitations = snapshot.data ?? [];

                      if (invitations.isEmpty) {
                        return _buildEmptyState(
                          'No pending invitations',
                          CupertinoIcons.bell,
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: invitations.length,
                        itemBuilder: (context, index) {
                          return _buildInvitationCard(invitations[index]);
                        },
                      );
                    },
                  ),

                  // History Tab
                  StreamBuilder<List<Trip>>(
                    stream: _convoyService
                        .getUserCompletedTrips(widget.currentUser.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }

                      final trips = snapshot.data ?? [];

                      if (trips.isEmpty) {
                        return _buildEmptyState(
                          'No completed trips',
                          CupertinoIcons.clock,
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: trips.length,
                        itemBuilder: (context, index) {
                          return _buildTripCard(trips[index]);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

