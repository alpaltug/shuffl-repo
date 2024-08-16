import "Person.dart";
class Car {
  int id;
  var passengers = [];
  int current_location;
  var pickups = [];
  var dropoffs = []; //can start with one

  Car(this.id, this.current_location);

  void travel(int location){
    for (int i = 0; i < passengers.length; i++){
      passengers[i].Move(location);
    }
  }
  void pickup(Person p){
    passengers.add(p);
    pickups.remove(this.current_location);
  }
  void dropoff(Person p){
    passengers.remove(p);
    dropoffs.remove(this.current_location);
  }
  void pickup_Mult(var p_list){
    for (int i = 0; i < p_list.length; i++){
      passengers.add(p_list[i]);
    }
    pickups.remove(this.current_location);
  }
  void dropoff_Mult(var p_list){
    for (int i = 0; i < p_list.length; i++){
      passengers.remove(p_list[i]);
    }
    dropoffs.remove(this.current_location);
  }
}