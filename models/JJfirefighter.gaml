/**
* Name: FireFighter
* Based on the internal empty template. 
* Author: Bond
* Tags: 
*/


model FireFighter

global {
    file shape_file_buildings <- file("../includes/Final building.shp");
    file shape_file_bounds <- file("../includes/JJarea.shp");
    file shape_file_roads <-file("../includes/CarRoadClean.shp");
	geometry shape <- envelope(shape_file_bounds);
	graph<geometry, geometry> road_network;
	graph<geometry, geometry> carroad_network;
    map<road,float> road_weights;
    map<road,float> carroad_weights;
    float step <- 10 #sec;
    int nb_people <- 500;
    int nb_fireman <- 10;
    float min_speed <- 2.0 #km / #h;
    float max_speed <- 5.0 #km / #h;
   // float fire_speed <- rnd(0.2,0.5)#km/#h; //0.24-0.5
    float fire_speed <- 0.45#km/#h;     
    float fire_dist <- 100.0#m;
    float min_speed_fireman <-5.0 #km/#h;
    float max_speed_fireman <-9.0 #km/#h;
    float min_speed_truck <-8.0 #km/#h;
    float max_speed_truck <-10.0 #km/#h;
    float min_fire_spread_rate <- 0.1;
    float max_fire_spread_rate <- 1.0;
    float fire_radius_risk <- 10#m;
    float fire_radius_effect <- 50#m; 
    float fire_ratio_radius_distance <- rnd(1,2)#m;
    int building_on_fire <- 0 ;
    int building_burned <- 0;
    int building_damaged <- 0;
    int building_risk <-0 update:building count(each.risk)  ;
    int building_ontime_fire <- 0update:building count(each.on_fire);
    int safe_people;
    int arrived_at_fire_count<- 0;
    int nb_firetruck <-1;
    int limit_firetruck<- 0;
    int nb_fire_man_in_truck <-5;

	cursor pointClicked;
	init {
		bool confirm <-user_confirm("Confirmation Box","Please select the fire location first.");
		create building from: shape_file_buildings with: [type::string(read ("builting"))] {
             if type="refugee camps" {
                color <- #lightgreen ;
            } 
            else if type="house" or type ="around_house" or type= "out_case" or type = "fire station" or type= "study_case"{
                color <- #gray;
            }
		}
		create road from: shape_file_roads;
		road_network <- as_edge_graph(road);
        road_weights <- road as_map (each::each.shape.perimeter);

		create fire_man_ex1 number:nb_fireman;
		create people number: nb_people;
		create fire_truck number: nb_firetruck;
		/*create fire {
            house_place <- one_of(building where (each.type = "study_case"));
            location <- (one_of(self.house_place)).location;
            }*/
		create cursor number:1 returns: temp with: [dummyRadius :: 3];
       pointClicked <- first(temp);
	}
	action draw_clicked_area_in_view_color
	{
		pointClicked.location <- #user_location;
		pointClicked.visibleViewColor <- true;
	}
	

	action hide_clicked_area
	{
		pointClicked.visibleViewColor <- false;
	}
	action set_fire_location 
	{
		list<building> selected_agents <- building overlapping (circle(3) at_location #user_location);
		ask selected_agents
		{
			color <- color = #gray? #red:#gray;
			click_location <-true;
        	create fire {
            house_place <- one_of(building where (each.click_location = true));
            location <- (one_of(self.house_place)).location;
        }	
        
		}
		
	}
	
}
species cursor  {
	int dummyRadius <- 3;
	bool visibleViewColor <- false;
	bool visibleViewShape <- false;
	init{
		
	}
	aspect aspect4ViewChangeColor {
		if visibleViewColor {draw circle(dummyRadius) color: #red;}
	}
	
}
species building {
	string type; 
	rgb color ;
	bool house_fire_truck <-false;
	bool target_truck<-false;
	bool outrisk <- false;
	bool risk <- false;
    bool on_fire <- false;
    bool burned <- false;
    bool pre_target_fireman <- false;
    bool extinguish <-false;
    bool click_location <- false;
    int height <- rnd(4,10);

	aspect base {
        if(risk and !on_fire and !burned){
            color <- #yellow;
        }
        else if(risk and on_fire and !burned){
            color <- #red;            
        }
        else if(on_fire and burned){
            color <- #black;
        }
        
        draw shape color: color;
    }
}

species road  {
	int users;
    float speed_coeff <- 1.0;
	aspect base {
		draw shape color: color ;
	}
}

species people skills:[moving]{
	building house_place <- one_of(building where (each.type="house" or each.type="around_house"));
	building refugee_place <- one_of(building where (each.type="refugee camps"));
	building new_house;
	bool is_alerted <-true; 
	float distance_travelled <- 0.0;
	bool safe <-false;
	bool near_fire <-false;
	bool died <- false;
	list<building> burning_buildings {
            return building where (each.on_fire);
        }
	init{
		speed <- rnd(min_speed,max_speed);
		location <-any_location_in(one_of(house_place));
	}
	 reflex fast_move when: is_alerted  {
	
		do goto target:refugee_place on: road_network move_weights:road_weights;
		 if(location = refugee_place.location ){
		 	if(safe_people < nb_people){
		 		is_alerted <- false;
		 	} 
        }
        
    }
   reflex check_path when: (current_path = nil) { 
            do die;
    }
    reflex people_died when: died{
    	do die;
    } 
 
	aspect base {
		draw circle(2) color: is_alerted? #red:#green border:#black;
	}
}

species fire_man_ex1 skills:[moving] {
    building station_place <- one_of(building where (each.type = "refugee camps"));
    rgb color <- #yellow;
    building target_building <- nil;
   	building new_target_building <-nil;
    fire target_fire <- nil;
    fire new_target_fire <- nil; 
    
    init {
        speed <- rnd(min_speed_fireman, max_speed_fireman);
        location <- any_location_in(one_of(station_place));
    }
	list<building> new_fire_target{
		return building where (each.on_fire);
	}
    reflex find_fire when: target_building = nil {
    target_building <- one_of(building where (each.on_fire = true)); 
    if (target_building != nil) {
        target_fire <- one_of(fire where (each.house_place = target_building)); 
        do goto target: target_fire.location on: road_network move_weights: road_weights;
        arrived_at_fire_count<-arrived_at_fire_count+1; 
        
    } else {
        write "No building on fire found.";
        
    }
}
    reflex move_to_fire when: target_building != nil {

    if (location = target_building.location and target_fire != nil) {
            target_fire.is_extinguished <- true; 
            target_fire.spreading <- false;
            target_building.on_fire <- false;
  //          target_building.burned <- false; 
   			target_building.pre_target_fireman<-true;
   		//	speed<-speed*rnd(min_fire_spread_rate,max_fire_spread_rate);  
            target_building <- one_of(building where (each.on_fire = true));
            if (target_building != nil) {
                target_fire <- one_of(fire where (each.house_place = target_building));
                do goto target: target_fire.location on: road_network move_weights: road_weights;
                arrived_at_fire_count<-arrived_at_fire_count+1; 
            }
            if(location = target_building.location){
            	do find_new_target();
            	
            }
            else {
            	
            }
        
    } else {
        do goto target: target_building.location on: road_network move_weights: road_weights; 
    }
}	
	action find_new_target {		
		loop build over: new_fire_target(){
		target_building <- one_of(building where (each.on_fire = true));
		if (target_building != nil) {
                target_fire <- one_of(fire where (each.house_place = target_building));
                do goto target: target_fire.location on: road_network move_weights: road_weights; 
            }		
		}
	}
	
    aspect base {
        draw triangle(8) color: #orange border:#black; 
    }
}
species fire_truck skills:[moving]{
	rgb color<-#blue;
	building target_building <-nil;
	building risk_building <-nil;
	fire target_fire <- nil;
	building new_building <-nil;
	bool set_house_fire_truck<-false;
	bool truck_stop <-false;
	building nearby_building <-nil;
	list<building> nearby_buildings{
		return building where (each distance_to self.location<2#m);
	}
	init{
		speed <-rnd(min_speed_truck,max_speed_truck);
		location <- any_location_in(one_of(building where (each.type="refugee camps")));
	}
	reflex find_fire when: target_building = nil {
    target_building <- one_of(building where (each.target_truck = true)); 
    if (target_building != nil) {
        target_fire <- one_of(fire where (each.house_place = target_building)); 
        do goto target: target_fire.location on: road_network move_weights: road_weights;
        arrived_at_fire_count<-arrived_at_fire_count+1; 
        
    } else {
        write "No building on fire found.";  
    }
	}
	action set_truck {
        new_building.house_fire_truck <- true;
        loop build over: nearby_buildings() {
            build.house_fire_truck <- true;
        }
        set_house_fire_truck <- true;
    }
    reflex move_to_fire when: target_building != nil {
    if (location = target_building.location) {
     	do stop;
     	do set_truck;
     	
        if (!empty(nearby_buildings)) {
        	target_building.risk<-false;
            create fire_man_in_truck number:5; 
            ask fire_man_in_truck {               
                location <- self.location; 
            }
            loop build  over:nearby_buildings(){
            	nearby_building.on_fire<-false;
            }
        }      
        target_building <- nil;
    } else {
        do goto target: target_building.location on: road_network move_weights: road_weights;
    }
}
	action stop{
		speed<-0#m/#s;
		truck_stop<-true;
	}
	action create_fireman {
		new_building <- one_of(building where (each.house_fire_truck = true) ); 
 		create fire_man_in_truck number: nb_fire_man_in_truck
       		{     
        }
}
/* reflex Request_reinforcements when : truck_stop and building_risk mod 10 = 5 and limit_firetruck <4  {
		do fire_out_control;
	}*/	
	action fire_out_control {
		limit_firetruck <- limit_firetruck + nb_firetruck ;
		create fire_truck number:1{
			
		}
	}
	aspect base {
		draw rectangle(9,6) color:color border:#black;
	}
}

species fire_man_in_truck parent:fire_man_ex1{ 
	building new_building <- one_of(building where (each.house_fire_truck = true)); 
    init {
    	speed <- rnd(min_speed_fireman, max_speed_fireman);
    	location <- new_building.location;
    	
    }
    aspect base {        
        draw triangle(8) color: color border: #black;     
    }
}
species fire {
    bool spreading <- true;
    bool set_house_on_truck<- false;
    bool set_outrisk <- false;
    bool set_risk <- false;
    bool set_on_fire <-true;
    bool  set_pre<-false;
    building house_place <- nil;
    bool is_extinguished <- false;
    people people_fire<-nil;
	string status <-nil;
	
	list<building>target_trucks {
     	return building where (each.type="around_house");
     }
     list<building>building_in_outrisk {
     	return building where (each distance_to house_place <  (fire_radius_risk*fire_ratio_radius_distance*5));
     }
    list<building> building_near_fire {
        return building where (each distance_to house_place < (fire_radius_risk*fire_ratio_radius_distance));
    }
    list<building> building_in_fire_range {
        return (building_near_fire() where (!each.on_fire)) overlapping self;
    }
	action target_truck_building{
		house_place.target_truck<-true;
		 loop build over: building_in_outrisk() where (each.type = "around_house")  {
            build.target_truck <- true;
        }
        set_house_on_truck <-true;
	}
    action set_outrisk_on_house{
		   house_place.outrisk<-true;
        loop build over: building_in_outrisk()  {
            build.outrisk <- true;          
        }
        set_outrisk <- true;
    }
    action set_risk_on_house {
        house_place.risk <- true;
        building_risk <- building_risk+1;
        loop build over: building_near_fire() {
            build.risk <- true;
        }
        set_risk <- true;
    }
    action set_on_fire_on_house {
        building_damaged <- building_damaged +1;
        house_place.on_fire <- true;
        set_on_fire <- true;
    }
    action count_on_fire{
    	building_on_fire <- building_on_fire + 1;
    	building_ontime_fire <- building_ontime_fire +1;
        building_damaged <- building_damaged +1;
    }
	action fire_man_present{
		house_place.pre_target_fireman<-true;
		loop build over: building_near_fire() {
            build.pre_target_fireman <- true;
        }
        set_pre <- true;
	}
  reflex spread when: spreading and !is_extinguished {
	if(!set_house_on_truck){
		do target_truck_building();
		
	}
     if (!set_outrisk) {
        do set_outrisk_on_house();
    }
    if (!set_risk) {
        do set_risk_on_house();
        
    }
    if (!set_on_fire) {
        do set_on_fire_on_house();
        do count_on_fire();
    }
    if (self.shape.width < fire_radius_effect) {
        shape <- shape buffer (fire_speed * step);
    } else {
        house_place.burned <- true;
        building_burned <-building_burned+1;
//      house_place.risk<-false;
 //       house_place.on_fire<-false;
//        spreading <- false;
        is_extinguished <- true;
        set_on_fire<- false;
        set_risk<-false;
    }
    if (!empty(building_in_fire_range) and !is_extinguished) {
        do spread_fire_to_another_build();
    }
}

action spread_fire_to_another_build {
    loop build over: building_in_fire_range() {
    	if(!build.pre_target_fireman and !build.extinguish  ){
    		 create fire {
            house_place <- build;
            location <- build.location;
        }       
       	 building_on_fire <- building_on_fire + 1;
       	 building_ontime_fire<-building_ontime_fire+1;
         build.on_fire <- true;        
    	}       
    }
}
    aspect base {
        draw shape color: rgb(255, 165, 0, 0.1) border: #red;
    }
}




experiment fireman_ex type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_bounds category: "GIS" ;
	parameter "NB People"	var: nb_people category: "Number" ;
	parameter "NB Firefighter" var:nb_fireman category:"Number"min: 5 max:30;
	output {
		display city_display type:opengl {
			species cursor transparency:0.9 aspect: aspect4ViewChangeColor;
			species building aspect: base ;
			species road aspect: base ;
			species people aspect: base;
			species fire aspect: base;
			species fire_man_ex1 aspect: base;
			event #mouse_down {ask simulation {do set_fire_location;}}  
			event #mouse_move {ask simulation {do draw_clicked_area_in_view_color;}} 
			event #mouse_exit {ask simulation {do hide_clicked_area;}}
		}
		monitor " Total Building risk" value:building_risk;
		monitor "Total Building on fire" value: building_on_fire;
        monitor "Total Building burned" value: building_burned;
        monitor "On Time Risk Building" value: building_risk-building_ontime_fire;
        monitor "On Time Fire Building" value:building_ontime_fire;
  //      monitor "House In Control" value: arrived_at_fire_count;         
        monitor "Time Step" value:step*cycle;
        
		
	}
}

experiment fireTruck_ex type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_bounds category: "GIS" ;
	parameter "NB People"	var: nb_people category: "Number" ;
	parameter "NB Fire Truck" var:nb_firetruck category:"Number"min: 1 max:5;
	output {
		display city_display type:opengl {
			species cursor transparency:0.9 aspect: aspect4ViewChangeColor;
			species building aspect: base ;
			species road aspect: base ;
			species people aspect: base;
			species fire aspect: base;
			species fire_truck aspect: base;
			species fire_man_in_truck aspect: base;
			event #mouse_down {ask simulation {do set_fire_location;}}  
			event #mouse_move {ask simulation {do draw_clicked_area_in_view_color;}} 
			event #mouse_exit {ask simulation {do hide_clicked_area;}}
		}
		monitor "Total Building risk" value:building_risk;
		monitor "Total Building on fire" value: building_on_fire;
        monitor "Total Building burned" value: building_burned;
     //   monitor "House In Control" value: arrived_at_fire_count;
        monitor "On Time Risk Building" value: building_risk-building_ontime_fire;
        monitor "On Time Fire Building" value:building_ontime_fire;      
        monitor "Time Step" value:step*cycle;
	}
}


