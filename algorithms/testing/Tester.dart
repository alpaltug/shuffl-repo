import "Car.dart";
import "Person.dart";
void main() {
  var ride_requests = [];
  var fleet = [];
  for (int i = 0; i < 10; i++){ //start with a fleet of 10 cars
  Car car = new Car(i, 0);
  fleet.add(car);
  }
  var bob_schools = ["UC Berkeley"];//placeholder person to get rid of later
  Person bob = new Person(0, 20, true, "UC Berkeley", 20, 18, 25, false, false, bob_schools, 5);
  ride_requests.add(bob);
  ride_requests.remove(bob);
  //create our map
  //Given a time period, start generating random requests across map
  //also implement a Djikstra's algorithm for computing shortest paths
}