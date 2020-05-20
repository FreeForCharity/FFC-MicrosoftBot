nuget restore
msbuild QnABot.sln -p:DeployOnBuild=true -p:PublishProfile=.\ffc-qna-maker-bot-Web-Deploy.pubxml -p:Password=mX13Le4sxcHWluoojxG97SbYBTXN5R2ycKyJnoblpQYNwhTblwPFJBHM92Hz

