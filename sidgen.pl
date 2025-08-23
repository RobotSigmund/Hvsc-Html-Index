#!c:/perl/bin/perl



use strict;
use Time::Local;



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
open(my $FILE, '>C64.htm');
print $FILE '<html><head><title>HVSC chronological order!</title></head>';
print $FILE '<body><!--' . "\n\n" . 'Generated ' . FormatTime() . '!' . "\n" . 'www.straumland.com' . "\n\n" . '--><pre><h1>High Voltage SID collection!</h1><a href="http://www.hvsc.c64.org/">www.hvsc.c64.org</a>' . "\n\n";
foreach my $i (0..$#filelist) {
	$filelist[$i] =~ s/\[songlength:(.+)\]/$songlengths{$1}/;
	print $FILE FillAlignRight(($i + 1), 6) . ' ' . $filelist[$i];
}
print $FILE "\n" . '</pre></body></html>' . "\n";
close($FILE);
print 'ok' . "\n";



print 'DONE!' . "\n\n";
print 'Open "C64.htm" in Chrome browser. It still supports opening local links with filetype selected software.' . "\n";
sleep(5);
exit;



# -----



sub ReadSonglengthsFile {
	my($songlengths_ref) = @_;
	
	# Open the songlengths file, put everything into referenced hash
	open(my $FILE, '<DOCUMENTS/Songlengths.md5') or die('ERROR - Can not read songlengths file');
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
		next if (($de eq ".") || ($de eq ".."));
		
		if (-d $folder."/".$de) {
			# Folder, do recursion
			readdirs($folder . '/' . $de, $filelist_ref);
			print '.';

		} elsif ($de =~ /\.sid$/i) {
			# SID file, add to array
			open(my $FILE, $folder . '/' . $de);
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
			push(@$filelist_ref, $sidfile_line_year . ' ' . FillAlignLeft($sidfile_line_title_link, $sidfile_line_title, 32) . ' ' . FillAlignLeft(HtmlWash($sidfile_line_author), $sidfile_line_author, 32) . ' ' . FillAlignLeft($sidfile_line_folder_link, $sidfile_line_folder, 42) . ' ' . $sidfile_line_songlength . "\n");
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



sub FillAlignRight {
	my($text, $width) = @_;
	
	while (length($text) < $width) {
		$text = ' ' . $text;
	}
	
	return $text;
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



sub FillAlignLeft {
	my($text, $length_text, $maxlength) = @_;
	
	my $append = '';
	$append = ' ' if (length($length_text) < $maxlength);
	while (length($length_text . $append) < $maxlength) {
		$append .= '.';
	}
	
	return($text . $append);
}
