use utf8;

{
# Enabled tasks, in this order they will be displayed
enabled_tasks => [
	{task => 'video_convert', max_points => 10, deadline => '2017-02-20 08:00'},
	{task => 'test', max_points => 10, deadline => '2017-02-20 08:00'},
],

# Tasks database (you may prepare tasks here at enable them later)
tasks => {
	'video_convert' => {
		name => 'Konverze videosbírky',
		short_desc => 'First test task to test the system',
		text => <<EOF
Vymyslete příkaz, který:
<ul>
	<li>Vezme všechny soubory ze složky s příponou <code>.avi</code>
	<li>Překonvertuje je do formátu MP4 (s příponou <code>.mp4</code>)
</ul>
EOF
	},
	'test' => {
		name => 'Another task',
		short_desc => 'This is displayed in the main table',
		text => 'Something more longer here...'
	}
}
};
