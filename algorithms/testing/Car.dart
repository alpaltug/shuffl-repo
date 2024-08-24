import "Person.dart";
class Car {
  int id;
  var passengers = [];
  int current_location;
  var pickups = [];
  var dropoffs = []; //can start with one

  Car(this.id, this.current_location);

  int getID(){
    return id;
  }

  int getLoc(){
    return current_location;
  }
  List getPassengers(){
    return passengers;
  }
  List getPickups(){
    return pickups;
  }
  List getDropOffs(){
    return dropoffs;
  }
  bool Empty(){
    return passengers.isEmpty && pickups.isEmpty;
  }

  void assign(Person p){
    pickups.add(p.getLocation());
  }

  void travel(int location){
    for (int i = 0; i < passengers.length; i++){
      passengers[i].Move(location);
    }
    current_location = location;
  }
  void pickup(Person p){
    passengers.add(p);
    pickups.remove(this.current_location);
    dropoffs.add(p.getDropOff());
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