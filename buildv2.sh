#!/bin/bash
sed -e "s/3EB0FF/3EBF5C/" -i "" src/main/resources/templates/fragments/layout.html
sed -e "s/<version>1.0/<version>2.0/" -i "" pom.xml

mvn clean package -DskipTests

sed -e "s/3EBF5C/3EB0FF/" -i "" src/main/resources/templates/fragments/layout.html
sed -e "s/<version>2.0/<version>1.0/" -i "" pom.xml

