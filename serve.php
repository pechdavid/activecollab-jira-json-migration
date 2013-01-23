<?php

require "../config/config.php";

mysql_connect(DB_HOST, DB_USER, DB_PASS);
mysql_select_db(DB_NAME);

$to_i = intval($_GET['file']);
$res = mysql_query("SELECT location FROM acx_attachments WHERE id = " . $to_i);

while($row = mysql_fetch_array($res))
{
	header('Content-Description: File Transfer');
	header('Content-Type: application/octet-stream');
	header('Content-Disposition: attachment');
	header('Content-Transfer-Encoding: binary');
	header('Expires: 0');
	header('Cache-Control: must-revalidate, post-check=0, pre-check=0');
	header('Pragma: public');
	header('Content-Length: ' . filesize($file));
	ob_clean();
	flush();
	readfile(ROOT . "/../upload/" . $row["location"]);
	exit;
}

mysql_close();

?>
