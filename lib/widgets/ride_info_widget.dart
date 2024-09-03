import 'package:flutter/material.dart';

class RideInfoWidget extends StatelessWidget {
  final String rideDetails;
  final String rideTimeText;
  final List<String> dropoffAddresses;

  const RideInfoWidget({
    Key? key,
    required this.rideDetails,
    required this.rideTimeText,
    required this.dropoffAddresses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0), // Reduced padding
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), // Reduced margin
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8.0), // Reduced border radius
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.4),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rideTimeText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16.0, // Reduced font size
            ),
          ),
          const SizedBox(height: 6.0), // Reduced spacing
          Text(
            'Details: $rideDetails',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14.0, // Reduced font size
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6.0),
          if (dropoffAddresses.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dropoff Locations:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0, // Reduced font size
                  ),
                ),
                ...dropoffAddresses.take(3).map((address) { // Limit to 3 addresses
                  return Text(
                    address,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.0, // Reduced font size
                    ),
                  );
                }).toList(),
                if (dropoffAddresses.length > 3)
                  const Text(
                    '...and more',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.0,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
