#!/bin/bash
## THIS SCRIPT WORKS WITH RESPONDER TO ALERT ON CAPTURED HASHES RELATING TO THE PHHISHING CAMPAIGNS
## DEFAULTS IF NOT FROM PHISHING DOCS
SlackURL=$(cat /var/www/config.txt |grep "SlackIncomingWebhookURL" | cut -d '"' -f 2);
SlackChannel=$(cat /var/www/config.txt |grep "slackchannel" | cut -d '"' -f 2);
APIURL=$(cat /var/www/config.txt |grep "APIDomain" | cut -d '"' -f 2);

files=$(cd /home/ubuntu/Responder/logs && ls *.txt | awk '{print $1}');

## CHECKS IF RESPONDER LOGS EXIST
IFS='
'
count=0
for item in $files
do
  file=$item
  count=$((count+1))
  IP=$(echo $item | cut -d "-" -f 4 | cut -d "." -f 1,2,3,4);
  Module=$(echo $item | cut -d "-" -f 3);
  HashType=$(echo $item | cut -d "-" -f 2);

  Hashes=$(cat /home/ubuntu/Responder/logs/$file);

  Query=$(mysql -u root phishingdocs -se "CALL MatchHashes('$IP','$Hashes');");

  Title=$(echo $Query | cut -f 1);
  Target=$(echo $Query | cut -f 2);
  Org=$(echo $Query | cut -f 3);
  Token=$(echo $Query | cut -f 4);
  Channel=$(echo $Query | cut -f 5);
  UUID=$(echo $Query | cut -f 6);

## SEE IF THE IP ADDRESS FOR THE CAPTURED HASH EXISTS IN EITHER CAMPAIGN (phishingdocs or fakesite)

if [ $Title = "PhishingDocs" ]
then
  message=$(echo "> *HIT!!* Captured a" $HashType "hash ("$Module") for" $Target "at" $Org "(<"$APIURL/phishingdocs/results?UUID=$UUID"|"$IP">)");
  curl -s -X POST --data-urlencode 'payload={"channel": "'$Channel'", "username": "HashBot", "text": "'$message'", "icon_emoji": ":hash:"}' $Token
  rm /home/ubuntu/Responder/logs/$file;
fi

if [ $Title = "FakeSite" ]
then
  message=$(echo "> *HIT!!* Captured a" $HashType "hash ("$Module") for "$Target" at <"$APIURL/results?project=$Target"|"$IP">");
  curl -s -X POST --data-urlencode 'payload={"channel": "'$SlackChannel'", "username": "HashBot", "text": "'$message'", "icon_emoji": ":hash:"}' $SlackURL
  rm /home/ubuntu/Responder/logs/$file;
fi

  if [ -z "$Title" ]
  then
## COMMENT THE NEXT TWO LINES OUT IF YOU DO NOT WISH TO BE NOTIFIED FOR OUT OF SCOPE HASHES
      message=$(echo "> Captured an out of scope" $HashType "hash ("$Module") at" $IP"\r\n> \`\`\`"$Hashes"\`\`\`");
      curl -s -X POST --data-urlencode 'payload={"channel": "'$SlackChannel'", "username": "HashBot", "text": "'$message'", "icon_emoji": ":hash:"}' $SlackURL
      rm /home/ubuntu/Responder/logs/$file;
  fi

done
