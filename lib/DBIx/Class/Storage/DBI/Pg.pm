package DBIx::Class::Storage::DBI::Pg;

use strict;
use warnings;

use DBD::Pg;

use base qw/DBIx::Class::Storage::DBI/;

# __PACKAGE__->load_components(qw/PK::Auto/);

# Warn about problematic versions of DBD::Pg
warn "DBD::Pg 1.49 is strongly recommended"
  if ($DBD::Pg::VERSION < 1.49);

sub _pg_last_insert_id {
  my ($dbh, $seq) = @_;
  $dbh->last_insert_id(undef,undef,undef,undef, {sequence => $seq});
}

sub last_insert_id {
  my ($self,$source,$col) = @_;
  my $seq = ($source->column_info($col)->{sequence} ||= $self->get_autoinc_seq($source,$col));
  $self->dbh_do(\&_pg_last_insert_id, $seq);
}

sub _pg_get_autoinc_seq {
  my ($dbh, $schema, $table, @pri) = @_;

  while (my $col = shift @pri) {
    my $info = $dbh->column_info(undef,$schema,$table,$col)->fetchrow_hashref;
    if(defined $info->{COLUMN_DEF} and
       $info->{COLUMN_DEF} =~ /^nextval\(+'([^']+)'::(?:text|regclass)\)/) {
      my $seq = $1;
      # may need to strip quotes -- see if this works
      return $seq =~ /\./ ? $seq : $info->{TABLE_SCHEM} . "." . $seq;
    }
  }
  return;
}

sub get_autoinc_seq {
  my ($self,$source,$col) = @_;
    
  my @pri = $source->primary_columns;
  my ($schema,$table) = $source->name =~ /^(.+)\.(.+)$/ ? ($1,$2)
    : (undef,$source->name);

  $self->dbh_do(\&_pg_get_autoinc_seq, $schema, $table, @pri);
}

sub sqlt_type {
  return 'PostgreSQL';
}

sub datetime_parser_type { return "DateTime::Format::Pg"; }

1;

=head1 NAME

DBIx::Class::Storage::DBI::Pg - Automatic primary key class for PostgreSQL

=head1 SYNOPSIS

  # In your table classes
  __PACKAGE__->load_components(qw/PK::Auto Core/);
  __PACKAGE__->set_primary_key('id');
  __PACKAGE__->sequence('mysequence');

=head1 DESCRIPTION

This class implements autoincrements for PostgreSQL.

=head1 AUTHORS

Marcus Ramberg <m.ramberg@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
