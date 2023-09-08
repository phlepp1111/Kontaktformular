import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import multer from "multer";
import AWS from "aws-sdk";

const app = express();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

//AWS Setup
AWS.config.region = "eu-central-1";
const dynamodb = new AWS.DynamoDB();
const s3 = new AWS.S3();

// Multer configuration
const storage = multer.memoryStorage(); // Speichert die Datei im Speicher. Sie können auch `multer.diskStorage()` verwenden, um Dateien auf der Festplatte zu speichern.
const upload = multer({
    storage: storage,
    limits: {
        fileSize: 2097152,
    },
});

app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "index.html"));
});

app.post("/submit-form", upload.single("image"), async (req, res) => {
    const formData = req.body;
    const uploadedFile = req.file;
    let nextId = 0;
    console.log("Form data: ", formData);

    const scanParams = {
        TableName: "BeschwerdeDaten",
        Select: "COUNT",
    };
    const count = await dynamodb.scan(scanParams).promise();
    console.log("Count:", count);
    console.log(typeof count);
    if (count.Count > 0) {
        console.log("Items found:", count.Count);
        // const highestId = parseInt(data.Items[0].id.N); // Extract the highest ID
        nextId = count.Count + 1;
    } else {
        // If no items are found, start with ID 1
        nextId = 1;
        console.log("No items found. Starting with ID 1.");
    }
    console.log("Next ID:", nextId);
    const ddbParams = {
        TableName: "BeschwerdeDaten",
        Item: {
            id: { N: nextId.toString() },
            vorname: { S: formData.vorname },
            nachname: { S: formData.nachname },
            email: { S: formData.email },
            telefon: { N: formData.telefon },
            betreff: { S: formData.betreff },
            beschwerdetext: { S: formData.beschwerdetext },
        },
    };
    dynamodb.putItem(ddbParams, (err, data) => {
        if (err) {
            console.error("Fehler beim Speichern in DynamoDB:", err);
        } else {
            console.log("Daten erfolgreich in DynamoDB gespeichert:", data);
        }
    });

    if (uploadedFile) {
        console.log("Uploaded file:", uploadedFile.originalname);
        const uploadParams = {
            Bucket: "beschwerdebilder",
            Key: "BeschwerdeBilder/" + uploadedFile.originalname,
            Body: uploadedFile.buffer,
        };
        s3.upload(uploadParams, (err, data) => {
            if (err) {
                console.error("Error uploading image to S3:", err);
                res.status(500).send("Error uploading image to S3");
            } else {
                console.log("Image uploaded successfully:", data.Location);
            }
        });
    } else {
        console.log("No file uploaded");
    }

    res.send("Form data received successfully.");
});

app.listen(3000, () => {
    console.log("Server läuft auf Port 3000");
});
