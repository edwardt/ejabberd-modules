#!/bin/bash
copy_beams(){
	if [ -z "$1" ]
	then
	   echo "~Must have folder argument"
 	else
	   echo "~ Start copying ebeam files from \"$1\"~"
	fi

	if [ -z "$2" ]
	then
	   echo "~Must have file type argument"
 	else
	   echo "~ Start copying \"$2\" files"
	fi

	rm -f filelist.txt
 	find $1 -name $2 >> filelist.txt
	for file in `cat filelist.txt`; do \cp -f "$file" ./ebeam; done	 

}

copy_all_deps_ebeam(){
	echo "Copy all ebeams from deps to a ebeam folder"
	copy_beams ./deps "*.beam"
}

copy_all_apps_ebeam(){
	echo "Copy all ebeams from apps to a ebeam folder"
	copy_beams ./apps "*.beam"
}

copy_all_deps_app(){
	echo "Copy all apps from deps to a ebeam folder"
	copy_beams ./deps "*.app"	
}

copy_all_apps_app(){
	echo "Copy all apps from deps to a ebeam folder"
	copy_beams ./apps "*.app"	
}

copy_all_json_rec(){
	echo "Copy all Json rec and its depedencies"
	copy_beams ./json_rec/deps/edown "*.app"
	copy_beams ./json_rec/deps/edown "*.beam"
	copy_beams ./json_rec/deps/parse_trans "*.app"
	copy_beams ./json_rec/deps/parse_trans "*.beam"
}


copy_all_rabbitmq(){
	echo "Copy all rabbitmq client and common lib"
	copy_beams ../rabbit_common "*.app"
	copy_beams ../rabbit_common "*.beam"
	copy_beams ../amqp_client "*.app"
	copy_beams ../amqp_client "*.beam"
}

copy_all_ebin(){
	echo "Copy all mod_spark_log_chat"
	copy_beams ebin "*.app"
	copy_beams ebin "*.beam"
}

check_remove_conflict_files(){

       \rm -f ./ebeam/jlib.beam 
}

tar_config_files(){
	tar -cvf conf.tar.gz ./conf
}

tar_ebeam_files(){
	tar -cvf ebeam.tar.gz ./ebeam
}

rm -rf ./ebeam & rmdir -v ./ebeam
mkdir -v ./ebeam
touch ./ebeam/jlib.beam

copy_all_deps_ebeam
copy_all_apps_ebeam
copy_all_deps_app
copy_all_apps_app
copy_all_json_rec
copy_all_rabbitmq
copy_all_ebin
check_remove_conflict_files
tar_config_files
tar_ebeam_files

