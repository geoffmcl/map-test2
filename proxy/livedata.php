<?php

// 20140103 - bump to 10 secs - 20131216 - bump to 6 (was a mean 2!)
//= This script does a lot of error trapping so only devs need true
define('SHOW_ERRORS', false);

error_reporting(SHOW_ERRORS ? E_ALL : 0);
ini_set('display_errors', SHOW_ERRORS ? '1' : '0');


define('CF_FLIGHTS_URL', 'http://mpserver15.flightgear.org/modules/fgtracker/interface.php?action=livewaypoints');

define('USE_CURL', extension_loaded('curl') );

//=====================================================
//= Load using Curl
if(USE_CURL){

	$ch = curl_init();
	curl_setopt($ch, CURLOPT_URL, CF_FLIGHTS_URL); 
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1); 
	curl_setopt($ch, CURLOPT_TIMEOUT, 10);
	curl_setopt($ch, CURLOPT_FAILONERROR, 0);
	$data = curl_exec($ch);
	$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
 
	if($data === FALSE){
		$error = curl_error($ch);
		$data = json_encode( array('success' => true, 'error' => $error) );

	}elseif($http_code  != 200){
		$error = curl_error($ch);
		$data = json_encode( array('success' => true, 'error' => $error) );
	}
	curl_close($ch);	

//=====================================================
//= Load using file_get_contents()
}else{

	if(!$data = file_get_contents(CF_FLIGHTS_URL)){
		$error = error_get_last();
		$data = json_encode( array('success' => true, 'error' => $error) );
	}
}

header('Content-Type: text/plain');
echo $data;

?>