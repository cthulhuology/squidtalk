package Pg::Proc;
use DBI;
use DBD::Pg;

my $proclist = "select proc.proname::text from pg_proc proc join pg_namespace namesp on proc.pronamespace = namesp.oid where namesp.nspname = ?";


