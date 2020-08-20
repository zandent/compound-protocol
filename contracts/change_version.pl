#!/usr/bin/perl
use strict;
use warnings;
use POSIX;

for(@ARGV){
	print("File $_ is parsed\n");
  open( my $main_fh, "<", "$_" ) or die $!;
  open( my $df_fh, ">", "$_.delete" ) or die $!;
  while (my $row = <$main_fh>) {
    if($row =~ /pragma solidity/){
      $row = "pragma solidity >=0.5.16;\n";
    }
    print {$df_fh} $row;
  }
  close $main_fh;
  close $df_fh;
  system("mv $_.delete $_");
}
