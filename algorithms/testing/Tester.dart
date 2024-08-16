import "dart:math";

//import "dart:collection";

import "package:collection/collection.dart";

import "Car.dart";
import "Person.dart";

int dim = 1000; //how many nodes? can modify globally from here

var rand = Random(); //random number Dart generator
var school_library = ["UC Berkeley", "Contra Costa", "Stanford", "UCSB", "UCLA", "Diablo Valley", "Sierra CC", "Santa Barbara CC", "Westmont College", "Laguna Blanca School"];
//above: schools passengers come from
//below: our map as a weighted adjacency list (could convert to distance array if needed)
var ourMap =  List<List>.generate(dim, (i) => List<dynamic>.generate(dim, (index) => null, growable: false), growable: false);

//NOT NECESSARY, SHOULD SUPPORT REPRIORITIZING
/*class PQueue {//for Djikstra's
  Queue ourQueue = new Queue();

  PQueue();
}*/

Person generate_passenger(){
  //randomly generate: pickup, dropoff (sufficiently far away), age, sex, school, school/age/sex/walking preferences
  //age design: tend to be in 20s, with variance from 18 to 50
  //formula: rand(0, 10) + 18 + max(0, rand(0, 200) - 160)
  int age = rand.nextInt(11) + 18 + max(0, rand.nextInt(200) - 160);
  //age preferences: take base age
  //min age: max(18, age - age/2*rand(0, 1))
  int minAge = max(18, age - (age~/2) * rand.nextInt(2));
  if(rand.nextInt(2) > 0){
    minAge = 18;
  }
  //max age: min(58, age + age/2*rand(0, 1))
  int maxAge = min(58, age + (age~/2) * rand.nextInt(2));
  if(rand.nextInt(2) > 0){
    maxAge = 58;
  }
  int pick = rand.nextInt(dim);//pickup
  int walk = rand.nextInt(10);//max-walking preference
  int male = rand.nextInt(2);
  int sex_preference = rand.nextInt(2);
  int school = rand.nextInt(10);
  int drop;
  var schools = [];
  if(rand.nextInt(2) == 1){
    for (int i = 0; i < 10; i++){
      schools.add(school_library[i]);
    }
  } else {
    schools.add(school_library[school]);
    for (int i = 0; i < 10; i++){
      if(i != school && rand.nextInt(10) == 7){
        schools.add(school_library[i]);
      }
    }
  }
  while (true){
    drop = rand.nextInt(dim);//dropoff
    if(dist(pick, drop) > walk){
      break;
    }
  }
  Person bob = new Person(pick, drop, (male != 0), school_library[school], age, minAge, maxAge, (sex_preference != 0), schools, walk);
  return bob;
}

//Setup for Djikstra's

List<int> dists = [];

var prev = [];

bool update(int u, int v, int w){
  bool updated = false;
  if (dists[u] + w < dists[v]){
    prev[v] = u;
    updated = true;
  }
  dists[v] = min(dists[v], dists[u] + w);
  return updated;
}

int dist(int a, int b){//Calculate distance between two nodes via Djikstra's
  dists = [];
  prev = [];
  for (int i = 0; i < dim; i++){
    dists.add(double.maxFinite.toInt());
  }
  for (int i = 0; i < dim; i++){
    prev.add(Null);
  }
  dists[a] = 0;
  HeapPriorityQueue checkers = HeapPriorityQueue();
  //checkers.add(0, a);
  while (!checkers.isEmpty){
    int u = checkers.removeFirst();
    /*if (u == b){
      int d = u;
      while(d != s){

      }
    }*/
    for (int i = 0; i < ourMap[u].length; i++){
      /*
      int v = G[u][i][0];
      int w = G[u][i][1];
      if update(u, v, w){
        checkers.insert(dists[v], v);
      }
      */
    }
  }
  //return dists[b];
  return 100;
}

void generateMap() {
  //Here we generate our map
}

void main() {
  var ride_requests = [];
  var fleet = [];
  for (int i = 0; i < 10; i++){ //start with a fleet of 10 cars
    Car car = new Car(i, 0);
    fleet.add(car);
  }
  var bob_schools = ["UC Berkeley"];//placeholder person to get rid of later
  Person bob = new Person(0, 20, true, "UC Berkeley", 20, 18, 25, false, bob_schools, 5);
  ride_requests.add(bob);
  ride_requests.remove(bob);
  //create our map
  /* 
  Create an nxn (maybe 1000x1000) nested 2-dimensional edge "distance" matrix
  We need a mechanism to somewhat represent "neighborhoods" of connected nodes, with the graph being fully connected
  Within neighborhoods interconnection should be more common. But, paths should be sparse (BUT EXIST) between different
  neighborhoods. */
  //Given a time period, start generating random requests across map
  /*
  We have a given period of time for the simulation to run. The lengthier, the better for recording results.

  Essentially, at random locations, people start requesting rides. Cars travel to pick them up, or group them and have them walk. */
  //also implement a Djikstra's algorithm for computing shortest paths
}