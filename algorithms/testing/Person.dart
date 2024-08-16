class Person {
  int pickup;
  int dropoff;
  int current_location;
  bool is_male;
  String school = "";
  int age;
  int min_age;
  int max_age;
  bool gender_preference;
  var acceptable_schools = [];
  int acceptable_walking;

  Person(this.pickup, this.dropoff, this.is_male, this.school, this.age, this.min_age, this.max_age, this.gender_preference, this.acceptable_schools, this.acceptable_walking) :
    this.current_location = pickup; //Initialize
  
  void Move(int location){
    this.current_location = location;
  }
  String getSchool(){
    return school;
  }
  /*int getID(){
    return id;
  }*/
  int getAge(){
    return age;
  }
  int get_young(){
    return min_age;
  }
  int getOld(){
    return max_age;
  }
  List getSchools(){
    return acceptable_schools;
  }
  bool biased(){
    return gender_preference;
  }
  bool is_Male(){
    return is_male;
  }
  int walk(){
    return acceptable_walking;
  }
  /*bool operator ==(Object other) {
    // TODO: implement ==
    return super == other;
  }*/
}