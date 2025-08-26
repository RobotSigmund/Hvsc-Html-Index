#!c:/perl/bin/perl

use strict;
use Time::Local;
use utf8;
use Encode;
use HTML::Entities;
use URI::Escape;

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
my $html_listjs_instance = '<script src="' . ((-e 'List.js/list.min.js') ? 'List.js/list.min.js' : 'https://cdnjs.cloudflare.com/ajax/libs/list.js/2.3.1/list.min.js') . '"></script>';
my $html_generated_datetime = 'Generated ' . FormatTime();
open(my $FILE, '>:encoding(UTF-8)', 'C64.html');
print $FILE <<EOM;
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>HVSC chronological order!</title>
$html_listjs_instance
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

$html_generated_datetime
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
var userList = new List('hvsc', options);
</script>
<p>Powered by <a href="https://listjs.com/">List.js</a></p>
</body>
</html>
EOM
close($FILE);
print 'ok' . "\n";



print 'DONE!' . "\n\n";
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
			
			# SID file
			open(my $FILE, '<:raw', $folder . '/' . $de);
			read($FILE, my $filecontent, 118);
			close($FILE);
			
			my $sidfile_released = FileContentParse($filecontent, 86, 32);

			# 86=0x56 'released' (We only evaluate the first 4 year-digits)
			# We expect to find four digits with maybe question mark on the last two digits
			my $sidfile_time = ($sidfile_released =~ /^(\d{2}[\d\?]{2})/) ? $1 : '1982 Non-conforming';
			
			# We have to set a value to non-specific dates for sorting, so correct as best we can
			$sidfile_time = 2000 if ($sidfile_time eq '200?');
			$sidfile_time = 1990 if ($sidfile_time eq '199?');
			$sidfile_time = 1982 if (($sidfile_time eq '198?') || ($sidfile_time eq '19??'));
			
			# Convert to unix time
			my $sidfile_time_seconds = timelocal(0, 0, 12, 1, 0, $sidfile_time);
			
			# Build output for html file
			my $sidfile_line_year = DateConversion($sidfile_time_seconds);
			
			# 22=0x16 'name'
			my $sidfile_title = FileContentParse($filecontent, 22, 32);
			my $sidfile_line_title_link = '<a href="' . $folder . '/' . $de . '">' . encode_entities($sidfile_title) . '</a>';
			
			# 54=0x36 'author'
			my $sidfile_author = encode_entities(FileContentParse($filecontent, 54, 32));
			my $sidfile_line_folder  = $folder . '/';
			my $sidfile_line_folder_link  = '<a href="' . uri_escape($sidfile_line_folder) . '" target="_blank">' . encode_entities($sidfile_line_folder) . '</a>';
			my $sidfile_line_songlength  = '[songlength:/' . $folder . '/' . $de . ']';
			
			# Format content and Add to array
			my $listentry = '<tr>';
			$listentry .= '<td class="id">[id]</td>';
			$listentry .= '<td class="released">' . $sidfile_line_year . '</td>';
			$listentry .= '<td class="title">' . $sidfile_line_title_link . '</td>';
			$listentry .= '<td class="author">' . $sidfile_author . '</td>';
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
	
	# Zero-byte trail, trim these from content
	$content =~ s/\x00+$//g;
	
	return(decode('cp1252', $content));	
}



sub DateConversion {
	my($seconds) = @_;
	
	my @td = gmtime($seconds);
	
	# Return only year YYYY
	return ($td[5] + 1900);
}



sub FormatTime {
	my(@td) = localtime(time());
	
	# Return YYYY-MM-DD hh-mm-ss
	return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $td[5] + 1900, $td[4] + 1, $td[3], $td[2], $td[1], $td[0]);
}
