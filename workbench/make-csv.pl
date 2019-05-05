#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

binmode STDOUT, ':utf8';
my $COL_SEP = ',';
#$COL_SEP = "\t";

#
# https://docs.google.com/spreadsheets/d/1QBGVh1q64FjumCdwaCYk_ghZwsnk9NgRLGnxcD-aKMk
# を作るためのやっつけスクリプト
#
{
    my %R;

    my $order = 0;
    my %col_year;

    # カウント
    open my $fh, '<:encoding(utf8)', 'toho-calendar-list.txt' or die;
    while (<$fh>) {
        chomp;
        next unless /^\d+/;
        my ($yyyy_mm, @names) = split;
        my ($year, $month) = split /-/, $yyyy_mm;
        $col_year{$year} = 1;

        my $solo_or_multi = (@names == 1) ? 'solo' : 'multi';
        for my $name (@names) {
            next if $name eq '?' || $name eq '-';
            $R{$name}->{order} //= ++$order;  # 登場順
            $R{$name}->{of}->{$year}->{appear} = 1;  # その年のカレンダーに登場した
            my $page_or_cover = ($month > 0) ? 'page' : 'cover';
            ++$R{$name}->{of}->{$year}->{$page_or_cover}->{$solo_or_multi};
        }
    }
    close $fh;

    # 集計
    for my $name (keys %R) {
        my @years = sort keys %{ $R{$name}->{of} };
        $R{$name}->{first_year} = $years[0];
        $R{$name}->{last_year}  = $years[-1];
        for my $year (@years) {
            no warnings 'uninitialized';
            $R{$name}->{total_page_solo}   += $R{$name}->{of}->{$year}->{page}->{solo};
            $R{$name}->{total_page_multi}  += $R{$name}->{of}->{$year}->{page}->{multi};
            $R{$name}->{total_cover_solo}  += $R{$name}->{of}->{$year}->{cover}->{solo};
            $R{$name}->{total_cover_multi} += $R{$name}->{of}->{$year}->{cover}->{multi};
            $R{$name}->{total_appear}      += $R{$name}->{of}->{$year}->{appear};
        }
    }

    # 名前の順番
    my @row_names = sort {
           $R{$a}->{first_year}        <=> $R{$b}->{first_year}
        || $R{$a}->{last_year}         <=> $R{$b}->{last_year}
        || $R{$a}->{total_page_solo}   <=> $R{$b}->{total_page_solo}
        || $R{$a}->{total_page_multi}  <=> $R{$b}->{total_page_multi}
        || $R{$a}->{total_cover_solo}  <=> $R{$b}->{total_cover_solo}
        || $R{$a}->{total_cover_multi} <=> $R{$b}->{total_cover_multi}
        || $R{$a}->{order}             <=> $R{$b}->{order}
    } keys %R;

    my @col_years = sort keys %col_year;

    # 出力
    for my $name (@row_names) {
        my @cells = ($name, $R{$name}->{total_appear});
        for my $year (@col_years) {
            my $doy = $R{$name}->{of}->{$year};
            # 勝手な重みづけ
            my $v = 0;
            no warnings 'uninitialized';
            $v += $doy->{cover}->{multi} * 1;
            $v += $doy->{cover}->{solo}  * 2;
            $v += $doy->{page}->{multi}  * 3;
            $v += $doy->{page}->{solo}   * 6;
            push @cells, ($v == 0) ? '' : $v;
        }
        print join($COL_SEP, @cells), "\n";
    }
}
