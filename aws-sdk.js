//Erstellen Sie eine AWS-Konfiguration:
//Stellen Sie sicher, dass Sie die AWS-SDK in Ihrem Node.js-Projekt installiert haben. Sie können dies mit dem Befehl npm install aws-sdk tun.

const AWS = require("aws-sdk");
AWS.config.update({
    region: "Ihre-Region",
    accessKeyId: "Ihr-Access-Key-ID",
    secretAccessKey: "Ihr-Geheimer-Zugriffsschlüssel",
});
const dynamodb = new AWS.DynamoDB.DocumentClient();

const params = {
    TableName: "BeschwerdeDaten",
    Item: {
        vorname: req.body.vorname,
        nachname: req.body.nachname,
        email: req.body.email,
        telefon: req.body.telefon,
        betreff: req.body.betreff,
        beschwerdetext: req.body.beschwerdetext,
    },
};

dynamodb.put(params, (err, data) => {
    if (err) {
        console.error("Fehler beim Speichern in DynamoDB:", err);
    } else {
        console.log("Daten erfolgreich in DynamoDB gespeichert:", data);
    }
});

const s3 = new AWS.S3();

const uploadParams = {
    Bucket: "Ihr-S3-Bucket-Name",
    Key: "Zielverzeichnis/" + req.files.image.name,
    Body: req.files.image.data,
    ContentType: req.files.image.mimetype,
};

s3.upload(uploadParams, (err, data) => {
    if (err) {
        console.error("Fehler beim Hochladen des Bildes in S3:", err);
    } else {
        console.log("Bild erfolgreich in S3 hochgeladen:", data.Location);
    }
});
