cat myFile.csv.notcorrect | sed 's/[ \t]*,[ \t]*/,/g' > FullCRMOutputNew.csv

http://ff-extractor.sourceforge.net/

$ sudo aptitude update
$ sudo aptitude install ffe

ffe -o output.xml -c csv2xml.fferc input.csv

$ more csv2xml.fferc
structure csv2xml {
    type separated ,
    output xml
    record record {
        field PRODUCT_ID
                field CUSTOMER_ID
                field CUSTOMER_SEGMENT_NAME
                field CUSTOMER_SEGMENT_ID
                field AMOUNT
                field ORDER_COUNT
    }
}

output xml {
    file_header "<RECORDS>\n"
    data "<%n>%t</%n>\n"
    record_header "<%r>\n"
    record_trailer "</%r>\n"
    indent " "
    file_trailer "</RECORDS>\n"
  }


