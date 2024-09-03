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
    String formattedDay = DateFormat('EEE').format(rideTime).toUpperCase();
    String formattedDate = DateFormat('MMM d').format(rideTime);
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
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white, // Background color for the calendar
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 20,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.red, // Red top part for the calendar
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      formattedDay,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // White text on red background
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
