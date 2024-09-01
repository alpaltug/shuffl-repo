// lib/widgets/ride_card.dart
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
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.yellow[700],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEE').format(rideTime).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d').format(rideTime),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat('h:mm a').format(rideTime),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup: ${ride['pickupLocations'].values.join(", ")}',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Dropoff: ${ride['dropoffLocations'].values.join(", ")}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.group, size: 16, color: Colors.black54),
                      const SizedBox(width: 5),
                      Text(
                        'Participants: ${participantUsernames.join(", ")}',
                        style: const TextStyle(color: Colors.black54),
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
