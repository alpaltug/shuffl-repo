import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final List<String> participantUsernames;

  const RideCard({
    required this.ride,
    required this.participantUsernames,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime rideTime = ride['timeOfRide'].toDate();
    String formattedDate = DateFormat('E, MMM d').format(rideTime);
    String formattedTime = DateFormat('h:mm a').format(rideTime);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      color: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white, // Remove background color for a cleaner look
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/calendar_icon.jpeg',
                      fit: BoxFit.cover,
                      color: Colors.grey.withOpacity(0.3), // Slight overlay for blending
                      colorBlendMode: BlendMode.modulate,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(rideTime).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87, // Make the text more prominent
                          ),
                        ),
                        Text(
                          DateFormat('MMM d').format(rideTime),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          DateFormat('h:mm a').format(rideTime),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup: ${ride['pickupLocations'].values.join(", ")}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Dropoff: ${ride['dropoffLocations'].values.join(", ")}',
                    style: const TextStyle(color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.group, size: 16, color: Colors.black54),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Participants: ${participantUsernames.join(", ")}',
                          style: const TextStyle(color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
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
