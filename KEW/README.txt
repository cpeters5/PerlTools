# This script processes query by year from Kew.
# Generates new and changed species and synonyms into a file.
#
# 1)  Fetch advance search results for Orchidaceae by year.
#       Currently manually copy source page to files and put in data/input
#
# 2)  Run RequestKEWbyyear1.pl (this script)
#       request content of "http://apps.kew.org/wcsp/namedetail.do?name_id=$pid"
#       output: data/pid1, /data/pid2, (intermedate results.
#               data/results/changes.dat and data/results/new.dat
#               data/results/newspecies.dat (final)
#       1. Extract and output
#           1. TODO: genus
#           2. DONE: Extract and output species with status accepted/not accepted (PID1)
#       3. DONE: compare PID1 with actual and output new.txt and changes.txt
#           1. output data/results/changed.txt if statuys changed
#           2. output data/results/new.txt if new PID
#       4. Logon to kew to get detail for new and changes
#           1. For new. extract remaining fields
#               if status = accepted or unplaced and type = species, output to /results/newspecies.dat (confirm if infra specific is captured)
#               if status = accepted or unplaced and type = hybrid, output to /results/newhybrid.dat TODO
#           2. For status changed. Extract remaining fields
#               if status changed to synonym, extract acc_id of accepted species
#                   1. update status in species
#                   2. add (pid, acc_id) to synonym
#                   3. if image exists, update pid to acc_id, and set source_file_name to genus+species
#               if status changed from synonym, extract all synonym spid's
#                   1. update status in species
#                   1. add pid to accepted
#                   2. if synonyms exist,
#                       1. if spid already exists, update acc_id to NEW.pid
#                       2. if new spid, check the current status of spid.
#                           1. If it is 'synonym' (normal), insert (spid, NEW.pid)
#                           2. If not 'synonym' (error) manually update status and follow #1
#           2. TODO: hybrid, output results/hybrid.dat
#           3. TODO: synonym
#
# 3)  Load newspecies.dat to orchid_species, orchid_grex (pid) and orchid_accepted (pid)
#
# 4)  For changed species, update database manually using getpid query.
#       For each pid in changed.dat
#       Delete from orchid_synonym where spid = new pid or acc_id = pid.
#       if current.status = synonym
#           From synonym.dat file, get all new spid where acc_id = pid.
#           Update orchid_species set (status distribution, physicology) to new values
#           insert into orchid_accepted (pid)
#           insert into orchid_synonym (pid, all new spid)
#       else if old status != synonym (new status = accepted or unplaced)
#           From synonym.dat file, get new acc_id where spid = pid.
#           Update orchid_species set (status) to synonym
#           update orchid_spchybrids (pid) to (acc_id)
#           update orchid_ancestordescendant set acc_id = new acc_pid where acc_id = pid
#           delete (pid) from orchid_accepted
#           insert into orchid_synonym (pid, acc_id)
#
# 5)  TODO: For Synonyms, Load data/results/newsynonym.dat to orchid_synonym(acc_id,spid)
#
# 6)  TODO: Natural hybrid
#           Manual load
#------