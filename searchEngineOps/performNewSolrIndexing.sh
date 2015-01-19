echo "Pulling Core tables from Oraqcle Database"
./pullCoreTables.sh

echo "Indexing all Products related data into XML database called Basex"
./indexProductsRawDataInBasex.sh

echo "Prepare Solr index data in xml"
./prepareSolrIndexData.sh

echo "Splitting files into multiple ones to expedidate indexing process"
./prepareSolrInputFiles.sh


echo "Now index All Migros data in SOLR"

./performSolrIndexing.sh


