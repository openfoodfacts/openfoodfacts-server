<?php
logError ( "Début du traitement\r\n" );
// Lecture du fichier de conf
include "configOpenFoodFacts.php";

// Filtre sur les images a envoyer vers le site
$query = "O dans ExportSiteFMFR";

//Récupération du nombre de médias disponibles pour pouvoir boucler dessus.
logError ( "Récupération du nombre de médias disponibles pour pouvoir boucler dessus\r\n" );
$content1 = RecupUrl ( "$urldam/api/v1/search/?oauth_token=$oauth_token&per_page=1&bases[]=25&query=$query" );
$content1 = json_decode ( $content1, true );
$nbdoc = $content1 ["response"] ["total_results"];

logError("nbdoc: " . $nbdoc);

// Recherche des médias dans la base Produit pour récupérer les ids.
$debut = 0;
$pas = 1000;

//$nbdoc = 10;

if ($pas > $nbdoc)
    $pas = $nbdoc;

$tab_id_record = array ();
$tab_media = $tab_erreur = array ();
while ( $debut < $nbdoc ) {
    // Appel API pour obtenir la liste des produits à récupérer
    logError("Appel API pour obtenir la liste des produits"); 	
    $content = RecupUrl ( "$urldam/api/v1/search/?oauth_token=$oauth_token&per_page=$pas&bases[]=25&offset_start=$debut&query=$query" );
    $content = json_decode ( $content, true );
    // Pour chaque média, récupération de l'id (record_id) et de son emplacement (databox_id)
    foreach ( $content ["response"] ["results"] ["records"] as $value ) {
        $tab_id_record [] = array (
                "record_id" => $value ["record_id"],
                "databox_id" => $value ["databox_id"] 
        );
    }
    $debut += $pas;
}

logError("Pour chaque média, récupération du nomGs1 et vérication image de référence unique");
// Pour chaque média, récupération du nomGs1 et vérication image de référence unique
foreach ( $tab_id_record as $key => $record ) {
    $base = $record ["databox_id"];
    $id = $record ["record_id"];

    // Appel API pour obtenir la fiche descriptive d'une image
    $urlcaption = "$urldam/api/v1/records/" . $base . "/" . $id . "/caption/";
    $token = "?oauth_token=$oauth_token";
    $servercaption = RecupUrl ( $urlcaption . $token );
    $caption = json_decode ( $servercaption, true );

    //Initialisation de la variable $nomgs1
    $nomgs1 = "";
    $count = 0;
    
    //Boucle sur les metadonnées retournées par l'API
    foreach ( $caption ["response"] ["caption_metadatas"] as $structure ) {
        switch ($structure ["meta_structure_id"]) {
            case 58 :
                $nomgs1 = $structure ["value"];
                $count++;
                break;
        }
        //Break lorsque le nomgs1 est trouvé
        if ( $count>0 ) break;
    }
    // Si le nom GS1 est vide, passage au produit suivant
    if (empty ( $nomgs1 )) 
        continue;
    
    //Extraction du nomgs1 sans le numero sequentiel dans $gs1racc, pour la verification de reference multiple
    $gs1racc=substr($nomgs1, 0, -4);
    
    //Si $gs1racc n'existe pas dans le tableau $tab_media ni dans le tableau $tab_erreur
    //Ajout des informations du produit (id, base, nomgs1) dans $tab_media
    if (empty ( $tab_media [$gs1racc] ) && ! array_key_exists ( $gs1racc, $tab_erreur )) {
        $tab_media [$gs1racc]["id"] = $id;
        $tab_media [$gs1racc]["base"] = $base;
        $tab_media [$gs1racc]["nomgs1"] = $nomgs1;
    }     // Sinon, erreur image de reference multiple
    else {
        unset ( $tab_media [$gs1racc] );
        $tab_erreur [$gs1racc] = $id;
    }
}

// Pour chaque media de $tab_media
// recherche de l'url de la sous definition normegs1

LogError("Pour chaque media recherche de l'url de la sous definition normegs1");
foreach ( $tab_media as $key => $record ) {
    $base = $record ["base"];
    $id = $record ["id"];
    $nomgs1 = $record ["nomgs1"];
    
    // Appel API pour obtenir les sous définitions d'une image
    $url = "$urldam/api/v1/records/" . $base . "/" . $id . "/embed/";
    $url .= "?oauth_token=$oauth_token";
    $server_output = RecupUrl ( $url );
    $server_output = json_decode ( $server_output, true );
    
    //Initialisation de la variable $url
    $url = "";
    foreach ( $server_output ["response"] ["embed"] as $structure ) {
        if ($structure ["name"] != "normegs1")
            continue;
        $url = $structure ["permalink"] ["url"];
    }
    
    /*
     * Traitement pour la récupération des images :
     * Le traitement ci-dessous télécharge les images dans un dossier $dossier
     */
    $dossier="download/";
    if (! empty ( $url )) {
        #downloadFile ( $url_dl, "./$dossier" . $nomgs1 . ".png" );
        downloadFile ( $url, "./$dossier" . $nomgs1 . ".png" );
    } else {
        logError ( "La sous definition Norme Gs1 n'existe pas pour l'image " . $nomgs1 . " (ID $id)\r\n" );
    }
}

//Log des erreurs des images de reference multiple
foreach ( $tab_erreur as $key => $value ) {
    $erreur = "Il existe plusieurs images de référence pour le GTIN " . $key . "\r\n";
    logError ( $erreur );
}

/**
 * Log le message $string dans le fichier ./logs/logOpenFoodFacts+datedujour.log
 * 
 * @param string $string            
 */
function logError($string) {
    // return true;
    error_reporting ( null );
    $date = date ( "d/m/Y H:i:s" );
    $filename = "./logs/logOpenFoodFacts" . date ( "Ymd" ) . ".log";
    $logfile = fopen ( $filename, "a+" );
    fputs ( $logfile, $date . " - " . $string );
    fclose ( $logfile );
    error_reporting ( E_ALL );
}

/**
 * Equivalent de file_gets_content avec un curl
 * 
 * @param String $url
 *            Url d'appel a l'API
 * @return String format JSON
 */
function RecupUrl($url) {
	logError("RecupUrl: " . $url . "\n");
    $ch = curl_init ();
    curl_setopt ( $ch, CURLOPT_SSL_VERIFYPEER, FALSE );
    curl_setopt ( $ch, CURLOPT_HEADER, false );
    curl_setopt ( $ch, CURLOPT_FOLLOWLOCATION, true );
    curl_setopt ( $ch, CURLOPT_URL, $url );
    curl_setopt ( $ch, CURLOPT_REFERER, $url );
    curl_setopt ( $ch, CURLOPT_RETURNTRANSFER, TRUE );
    $data = curl_exec ( $ch );
    curl_close ( $ch );
    
    return $data;
}

/**
 * Dépose le fichier $url dans le dossier $path
 * 
 * @param String $url
 *            Url a telecharger
 * @param String $filename
 *            chemin et nom du fichier a creer
 */
function downloadFile($url, $filename) {
    logError("downloadFile url " . $url . " - filename " . $filename . "\n");
    $newfname = $filename;
    $file = fopen ( $url, 'rb' );
    if ($file) {
        $newf = fopen ( $newfname, 'wb' );
        if ($newf) {
            while ( ! feof ( $file ) ) {
                fwrite ( $newf, fread ( $file, 1024 * 8 ), 1024 * 8 );
            }
        }
    }
    if ($file) {
        fclose ( $file );
    }
    if ($newf) {
        fclose ( $newf );
    }
}

?>
