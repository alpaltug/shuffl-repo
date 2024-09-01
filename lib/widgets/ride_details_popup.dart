import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RideDetailsPopup extends StatelessWidget {
  final DocumentSnapshot ride;
  final List<Map<String, String>> participants;
  final VoidCallback onJoinRide;

  const RideDetailsPopup({
    Key? key,
    required this.ride,
    required this.participants,
    required this.onJoinRide,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final DateTime rideTime = (ride['timeOfRide'] as Timestamp).toDate();
    final String formattedDate = DateFormat('d MMMM, yyyy').format(rideTime);
    final String formattedTime = DateFormat('h:mm a').format(rideTime);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ride Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            '$formattedDate at $formattedTime',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Pickup: ${ride['pickupLocations'].values.join(", ")}',
            style: const TextStyle(color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Dropoff: ${ride['dropoffLocations'].values.join(", ")}',
            style: const TextStyle(color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'Participants:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80, // Adjust the height based on the number of participants
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final participant = participants[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundImage: participant['imageUrl'] != null &&
                                participant['imageUrl']!.isNotEmpty
                            ? NetworkImage(participant['imageUrl']!)
                            : const AssetImage('assets/icons/ShuffleLogo.jpeg')
                                as ImageProvider,
                        radius: 25,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        participant['username'] ?? '',
                        style: const TextStyle(color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onJoinRide,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 15.0),
            ),
            child: const Text(
              'Join Ride',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
