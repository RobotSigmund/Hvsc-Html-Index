#!c:/perl/bin/perl

use strict;
use Time::Local;
use utf8;

# Win11 cmd.exe char-encoding. Use "chcp" to check.
use open qw(:std :encoding(cp437));



$| = 1;



print 'Reading songlengths...';
my %songlengths;
ReadSonglengthsFile(\%songlengths);
print 'ok' . "\n";



print 'Traversing tree...';
my @filelist;
readdirs('DEMOS', \@filelist);
readdirs('GAMES', \@filelist);
readdirs('MUSICIANS', \@filelist);
print 'ok, found ' . ($#filelist + 1) . ' sid-files' . "\n";



print 'Sorting list...';
@filelist = sort { $b cmp $a } @filelist;
print 'ok' . "\n";



print 'Generating HTML...';
open(my $FILE, '>:encoding(UTF-8)', 'C64.html');
print $FILE <<EOM;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>HVSC chronological order!</title>
<script src="List.js/list.min.js"></script>
<style>
body, th, td {
font-family: monospace;
text-align: left;
white-space: nowrap;
}
table {
border-collapse: collapse;
}
tr:nth-child(even) {
background-color: #f5f5f5;
}
th {
background-color: #eeeeee;
}
.sort-link {
text-decoration: none;
}
</style>
</head>
<body>
<!--

EOM
print $FILE 'Generated ' . FormatTime() . "\n";
print $FILE <<EOM;
www.straumland.com

-->
<h1>High Voltage SID collection!</h1>
<p><a href="http://www.hvsc.c64.org/">www.hvsc.c64.org</a></p>
<div id="hvsc">
<input class="search" placeholder="Search" />
<table>
<thead>
<tr>
<th>Id <a href="#" class="sort-link" onclick="userList.sort(['id'], { order: 'asc' }); return false;">▲</a> <a href="#" class="sort-link" onclick="userList.sort(['id'], { order: 'desc' }); return false;">▼</a></th>
<th>Released <a href="#" class="sort-link" onclick="userList.sort(['released'], { order: 'asc' }); return false;">▲</a> <a href="#" class="sort-link" onclick="userList.sort(['released'], { order: 'desc' }); return false;">▼</a></th>
<th>Title <a href="#" class="sort-link" onclick="userList.sort(['title'], { order: 'asc' }); return false;">▲</a> <a href="#" class="sort-link" onclick="userList.sort(['title'], { order: 'desc' }); return false;">▼</a></th>
<th>Author <a href="#" class="sort-link" onclick="userList.sort(['author'], { order: 'asc' }); return false;">▲</a> <a href="#" class="sort-link" onclick="userList.sort(['author'], { order: 'desc' }); return false;">▼</a></th>
<th>Folder <a href="#" class="sort-link" onclick="userList.sort(['folder'], { order: 'asc' }); return false;">▲</a> <a href="#" class="sort-link" onclick="userList.sort(['folder'], { order: 'desc' }); return false;">▼</a></th>
<th>Songlength</th>
</tr>
</thead>
<tbody class="list">
EOM
foreach my $i (0..$#filelist) {
	
	# Change [Id] to id-value to first column
	my $id = ($i + 1);
	$filelist[$i] =~ s/\[id\]/$id/;
	
	# Change [songlength:/path/] to previously read value
	$filelist[$i] =~ s/\[songlength:(.+)\]/$songlengths{$1}/;
	
	print $FILE $filelist[$i];
}
print $FILE <<EOM;
</tbody>
</table>
</div>
<script>
var options = {
valueNames: [ 'id', 'released', 'title', 'author', 'folder', 'songlength' ]
};
var userList = new List(\'hvsc\', options);
</script>
<p>Powered by <a href="https://listjs.com/">List.js</a></p>
</body>
</html>
EOM
close($FILE);
print 'ok' . "\n";



print 'DONE!' . "\n\n";
print 'Open "C64.html" in Chrome browser. It still supports opening local links with filetype selected software.' . "\n";
sleep(5);
exit;



# -----



sub ReadSonglengthsFile {
	my($songlengths_ref) = @_;
	
	# Open the songlengths file, put everything into referenced hash
	open(my $FILE, '<:encoding(UTF-8)', 'DOCUMENTS/Songlengths.md5') or die('ERROR - Can not read songlengths file');
	while(my $fileline = <$FILE>) {
		if ($fileline =~ /;\s(.+\.sid)/i) {
			my $filename = $1;
			$fileline = <$FILE>;
			$fileline =~ /=(.+)$/;
			$songlengths_ref->{$filename} = $1;
		}	
	}
	close($FILE);
}



sub readdirs {
	my($folder, $filelist_ref) = @_;
	
	# Open dir
	opendir(my $DIR, $folder);
	foreach my $de (readdir($DIR)) {
		next if (($de eq '.') || ($de eq '..'));
		
		if (-d $folder . '/' . $de) {
			# Folder, do recursion
			readdirs($folder . '/' . $de, $filelist_ref);
			print '.';

		} elsif ($de =~ /\.sid$/i) {
			# SID file, add to array
			open(my $FILE, '<:raw:encoding(cp1252)', $folder . '/' . $de);
			read($FILE, my $filecontent, 118);
			close($FILE);
			
			substr($filecontent, 86, 32) =~ /(\d{2,4}\?{0,2})/;
			my $sidfile_time = $1;
			
			# Sidfiles are really not very consistent on dating, so we try to correct before converting to date
			$sidfile_time = 2000 if ($sidfile_time eq "200?");
			$sidfile_time = 1990 if ($sidfile_time eq "199?");
			$sidfile_time = 1982 if (($sidfile_time eq "198?") || ($sidfile_time eq "19??"));
			$sidfile_time = $sidfile_time + 1900 if (($sidfile_time > 50) && ($sidfile_time < 100));
			$sidfile_time = $sidfile_time + 2000 if (($sidfile_time < 50) && ($sidfile_time >= 0));
			
			# Convert to unix time
			my $sidfile_time_seconds = timelocal(0, 0, 12, 1, 0, $sidfile_time);
			
			# Build output for html file
			my $sidfile_line_year = DateConversion($sidfile_time_seconds);
			my $sidfile_line_title = FileContentParse($filecontent, 22, 32);
			my $sidfile_line_title_link = '<a href="' . $folder . '/' . $de . '">' . HtmlWash($sidfile_line_title) . '</a>';
			my $sidfile_line_author = FileContentParse($filecontent, 54, 32);
			my $sidfile_line_folder  = $folder . '/';
			my $sidfile_line_folder_link  = '<a href="' . $sidfile_line_folder . '" target="_blank">' . HtmlWash($sidfile_line_folder) . '</a>';
			my $sidfile_line_songlength  = '[songlength:/' . $folder . '/' . $de . ']';
			
			# Format content and Add to array
			my $listentry = '<tr>';
			$listentry .= '<td class="id">[id]</td>';
			$listentry .= '<td class="released">' . $sidfile_line_year . '</td>';
			$listentry .= '<td class="title">' . $sidfile_line_title_link . '</td>';
			$listentry .= '<td class="author">' . HtmlWash($sidfile_line_author) . '</td>';
			$listentry .= '<td class="folder">' . $sidfile_line_folder_link . '</td>';
			$listentry .= '<td class="songlength">' . $sidfile_line_songlength . '</td>';
			$listentry .= '</tr>' . "\n";
			
			push(@$filelist_ref, $listentry);
		}
	}
	closedir($DIR);
}



sub FileContentParse {
	my($filecontent, $start, $length) = @_;
	
	my $content = substr($filecontent, $start, $length);
	$content =~ s/\0//gi;
	
	return($content);	
}



sub DateConversion {
	my($seconds) = @_;
	
	my @td = gmtime($seconds);
	
	return ($td[5] + 1900);
}



sub FormatTime {
	my(@td) = localtime(time());
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $td[5] + 1900, $td[4] + 1, $td[3], $td[2], $td[1], $td[0]);
}



sub HtmlWash {
	my($text) = @_;
	
	$text =~ s/</&lt;/gi;
	$text =~ s/>/&gt;/gi;
	
	return $text;
}
