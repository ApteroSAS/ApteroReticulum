import sys
import os
    
dockerImage = "aptero-reticulum"
registry = "registry.aptero.co"
c = os.system

if(sys.argv[1] == "build"):
    os.system("docker build -t "+dockerImage+" .")
 
elif(sys.argv[1] == "build_no_cache"):
    os.system("docker build --no-cache --progress=plain -t "+dockerImage+" .")

elif(sys.argv[1] == "publish"):
    version = sys.argv[2]
    c("docker build -t "+dockerImage+" .") 
    c("docker login")
    c("docker tag "+dockerImage+":latest "+registry+"/"+dockerImage+":latest")
    c("docker push "+registry+"/"+dockerImage+":latest")

    c("docker tag "+dockerImage+":latest "+registry+"/"+dockerImage+":"+version)
    c("docker push "+registry+"/"+dockerImage+":"+version)

else:
    print("invalid usage");