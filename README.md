# eMBRHelper
Decision support resource that delineates all known paths for the degredation of a named environmental contaminant, to help bioremediation researchers to make informed decisions capable of influencing the direction and outcomes of remediation exercises.
At the coundationof this is the construction of a comprehensive biodegradation network created by combining all reactions in UMBBD (now EAWAG-BBD) and the 'Zenobiotic degradation and metabolic' reactions in KEGG. Stored as a SIF file.
Scripts used in extracting these reactions prior to their merging are contained in the branch 'network_creation'.

The branch 'database scripts' contain scripts used in the creation of and the population of this resource's underlying mySQL database. The scripts will need to be run in the prescribed order. 
1. eMBR_compounds.pl
2. enzymes_UMBBD.pl
3. reactions_populate.pl
4. participates_in_populate.pl
5. UMBBD_microbes.pl
6. rxn_pathway.pl
7. enzymes_in.pl
8. checkingr.pl
9. Bsd_entries_populate.pl
10. umbkegg_go.pl

