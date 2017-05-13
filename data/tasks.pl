use utf8;
{
bonuses => [
	{bonus => 'activity', name => 'Aktivita v hodině'},
	{bonus => 'other', name => 'Ostatní'},
],

# Enabled tasks, in this order they will be displayed
enabled_tasks => [
	{task => 'video_convert', max_points => 10, deadline => '2017-02-22 08:00', show_solution => 1},
	{task => 'test', max_points => 10, deadline => '2017-02-20 08:00'},
],

# Tasks database (you may prepare tasks here at enable them later)
tasks => {
	'video_convert' => {
		name => 'Konverze videosbírky',
		short_desc => 'First test task to test the system',
		text => <<EOF,
Vymyslete příkaz, který:
<ul>
	<li>Vezme všechny soubory ze složky s příponou <code>.avi</code>
	<li>Překonvertuje je do formátu MP4 (s příponou <code>.mp4</code>)
</ul>
EOF
		solution => 'Blahoslaven budiž ffmpeg:',
		solution_code => <<'EOF'
for a in *.avi; do ffmpeg -i "$a" "${a/.avi}.mp4"; done
EOF
	},
	'test' => {
		name => 'Another task',
		short_desc => 'This is displayed in the main table',
		text => 'Something more longer here...',
		solution => 'Prepared solution, but yet not showed, because there is no show_solution => 1 in enabled tasks above.',
		solution_code => 'There should be some code...'
	}
}
};
