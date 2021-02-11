#! /bin/bash

######################################
# Scala - Maven create a Scala project archetype
# https://youtu.be/jguADLTaWB0
# 0:00 - check version to verify Maven is installed
# 1:39 - choose a location for you projects (can be anywhere)
# 3:32 - terminal mvn command to create a Scala project archetype
# 16:36 - terminal tree command to check archetype directory and file structure of newly created project
# 20:33 - pom.xml file overview
# 23:49 - explore the Maven .m2 repository directory
# 26:42 - access the Maven scala console
# 31:19 - to build jar files then add the Maven Assembly Plugin to the pom.xml (includes config updates like path for mainClass)
# 40:32 - compile Scala (hello world default app) and build a jar file
# 43:34 - various ways to run build, Scala console or jar file (as well as inclusion of command line arguments)
# 51:09 - here I walk you through an automated bash script I've written that can create any archetype project, custom update a pom.xml file and add any custom resource directories

# Scala - Install Apache Maven on Linux, Ubuntu/ Debian
# https://youtu.be/A5kRljCASW0

# how to this script works
# 1. will create a project 
# 2. will write dependencies and plugins to your pom file
#       will look for any file with extension .xml
#       ensure the xml file contains no more than one item

# to the run the script
# bash /your/path.../maven/project.sh "<mvn command to create a project>"

# https://twitter.com/datyrlab
#####################################

# variables
#####################################
if  [[ $1 ]]; then 
    
    mavendirectory=`dirname $0`
    mavencommand="$1"
    pomitemdirectory="${mavendirectory}/pom-items"  
    maven_assembly_plugin="${mavendirectory}/pom-items/pom-plugin-maven-assembly-plugin.xml"

    #projectdirectory="${mavendirectory}/projects" # create projects dir inside the maven directory
    projectdirectory=$(echo ${mavendirectory%/*}"/projects") # create projects dir outside the maven directory
    #projectdirectory="<or set a preferred location>"

    projectname=$(echo $mavencommand | sed -r 's/.*DartifactId=([^ ]+).*/\1/')
    projectfolder="${projectdirectory}/${projectname}" # full path to your project
    projectpomfile="${projectdirectory}/${projectname}/pom.xml"
    
    #<mainClass> - we set this value in our maven-assembly-plugin
    mainclass=$(echo $mavencommand | sed -r 's/.*DgroupId=([^ ]+).*/\1/')
    mainclass="${mainclass}.App" # App is the default main class that is created
   
    # resource folders
    resourcesdirectory="${projectdirectory}/${projectname}/src/main/resources"
    
    # resource subdirectories - add more directories
    resource_subdirectories=(
        "/config"
    )

fi

# uncomment to delete your .m2 directory for a complete restart
# if [ -f ~/.m2 ]; then rm -rf ~/.m2i; fi

# functions
#####################################
function maven_project(){
    
    if  [[ $1 ]]; then MAVENCOMMAND=$1; fi    
    if  [[ $2 ]]; then PROJECTDIRECTORY=$2; fi    
    if  [[ $3 ]]; then PROJECTFOLDER=$3; fi    
    if  [[ $4 ]]; then RESOURCESDIRECTORY=$4; fi    
    if  [[ $5 ]]; then eval "declare -A RESOURCE_SUBDIRECTORIES="${5#*=}; fi

    # is maven installed
    verify=$(mvn -version)
    
    if [[ ! ${verify} =~ "Apache Maven" ]]; then
        echo -e "\nmaven is not installed\n"

    else
        if [ ! -d ${PROJECTDIRECTORY} ]; then
            mkdir ${PROJECTDIRECTORY}        
        fi

        # create project if directory doesn't exist
        if [ ! -d ${PROJECTFOLDER} ]; then
            cd ${PROJECTDIRECTORY}
            pwd # show current directory
            eval $MAVENCOMMAND

        else
            echo -e "\nproject already exists"

        fi  
         
        # resources directories
        if [ -d ${PROJECTFOLDER} ]; then

            if [ ! -d ${RESOURCESDIRECTORY} ]; then
                mkdir ${RESOURCESDIRECTORY}        
                echo -e "created resource directory: ${RESOURCESDIRECTORY}"
            fi
            
            if  [[ $RESOURCE_SUBDIRECTORIES ]]; then
                for sub in "${RESOURCE_SUBDIRECTORIES=[@]}"; do
                    if [ ! -d ${RESOURCESDIRECTORY}${sub} ]; then
                        mkdir -p ${RESOURCESDIRECTORY}${sub}        
                        echo -e "created resource subdirectory: ${RESOURCESDIRECTORY}${sub}"
                    fi
                done
            fi

        fi
        
    fi
    
    
}

function maven_mainclass(){
    
    if  [[ $1 ]]; then MAVEN_ASSEMBLY_PLUGIN=$1; fi    
    if  [[ $2 ]]; then MAINCLASS=$2; fi    
    
    if [ -f ${MAVEN_ASSEMBLY_PLUGIN} ]; then
        mainclassstr="<mainClass>$MAINCLASS<\/mainClass>"
        sed -i -r "s/<mainClass>.*?<\/mainClass>/$mainclassstr/g" ${MAVEN_ASSEMBLY_PLUGIN}
                        
    fi

}

function update_pom(){
    
    if  [[ $1 ]]; then POMITEMFILE=$1; fi    
    if  [[ $2 ]]; then PROJECTPOMFILE=$2; fi    
    
    # looks for xml comment in pom item file (url page of plugin or dependency)
    search=$(grep -P "<!--.*?-->" $POMITEMFILE)
    
    # open pom item 
    POMITEMCONTENT=$(cat ${POMITEMFILE})
    POMITEMCONTENT="${POMITEMCONTENT##*( )}"
    POMITEMCONTENT="${POMITEMCONTENT%%*( )}"
   
    if  [[ $search ]]; then    
    
        if grep -Fxq "$search" ${PROJECTPOMFILE} # search for pom item in destination pom file
        then
            echo -e "already added: $search"

        else
            POMITEMCONTENT="$POMITEMCONTENT"$'\n' # add a trailing line break to each item, comment out if prefered

            if [[ $POMITEMCONTENT =~ "<dependency>" ]]; then
                # add item after last match
                # awk causes issues with escaping strings so insert this string then replace it after
                full_string=$(awk 'NR == FNR {
                    if ($0 ~ /<\/dependency>/)
                        x=FNR+1
                        next
                }
                FNR == x {
                    printf "\nINSERT_NEW_DEPENDENCY_HERE"
                }1' $PROJECTPOMFILE $PROJECTPOMFILE)
                full_string="${full_string//INSERT_NEW_DEPENDENCY_HERE/$POMITEMCONTENT}"
             
            elif [[ $POMITEMCONTENT =~ "<plugin>" ]]; then
                full_string=$(awk 'NR == FNR {
                    if ($0 ~ /<\/plugin>/)
                        x=FNR+1
                        next
                }
                FNR == x {
                    printf "\nINSERT_NEW_PLUGIN_HERE"
                }1' $PROJECTPOMFILE $PROJECTPOMFILE)
                full_string="${full_string//INSERT_NEW_PLUGIN_HERE/$POMITEMCONTENT}"

            elif [[ $POMITEMCONTENT =~ "<resource>" ]]; then
                if ! grep -Fxq "<resources>" ${PROJECTPOMFILE}
                then
                    POMITEMCONTENT="<resources>"$'\n'"${POMITEMCONTENT}</resources>"$'\n\n'
                    
                    full_string=$(awk 'NR == FNR {
                        if ($0 ~ /<\/testSourceDirectory>/)
                            x=FNR+1
                            next
                    }
                    FNR == x {
                        printf "\nINSERT_NEW_RESOURCE_HERE"
                    }1' $PROJECTPOMFILE $PROJECTPOMFILE)
                
                else
                    
                    full_string=$(awk 'NR == FNR {
                        if ($0 ~ /<\/resource>/)
                            x=FNR+1
                            next
                    }
                    FNR == x {
                        printf "\nINSERT_NEW_RESOURCE_HERE"
                    }1' $PROJECTPOMFILE $PROJECTPOMFILE)
                
                fi
                
                full_string="${full_string//INSERT_NEW_RESOURCE_HERE/$POMITEMCONTENT}"
            
            fi
            
            echo "${full_string}" > $PROJECTPOMFILE
            echo -e "adding to pom file: ${search}" 
        
        fi
    
    else
        echo -e "no item found: $POMITEMFILE"
    
    fi

}

function maven_pom(){
    
    if  [[ $1 ]]; then POMITEMDIRECTORY=$1; fi    
    if  [[ $2 ]]; then PROJECTPOMFILE=$2; fi    
    
    if [ -f ${PROJECTPOMFILE} ]; then
        echo -e "------------------------------------------------"
        echo -e "your project pom file: ${PROJECTPOMFILE}"
        
        if [ -d ${POMITEMDIRECTORY} ]; then
            IGNORE="ignore-" # add regex here to ignore file names
            if [ "$(ls ${POMITEMDIRECTORY} -1 | grep -v ${IGNORE})" ]; then

                filelist=($(ls ${POMITEMDIRECTORY} -1 | grep -v ${IGNORE}))

                for file in "${filelist[@]}"; do 
                     
                    if [[ $file =~ ".xml" ]]; then
                        pomitemfile="${POMITEMDIRECTORY}/${file}"
                        update_pom "${pomitemfile}" "${PROJECTPOMFILE}"
                        
                    fi

                done

            fi

        fi
    
    else
        echo -e "pom file doesn't exist"

    fi

}

#####################################

if  [[ $mavencommand ]]; then 
    
    # create project
    maven_project "${mavencommand}" "${projectdirectory}" "${projectfolder}" "${resourcesdirectory}" "$(declare -p resource_subdirectories)"
    
    # update pom file
    maven_mainclass "${maven_assembly_plugin}" "${mainclass}" 
    maven_pom "${pomitemdirectory}" "${projectpomfile}" 

fi


