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

// Multer configuration
const storage = multer.memoryStorage(); // Speichert die Datei im Speicher. Sie können auch `multer.diskStorage()` verwenden, um Dateien auf der Festplatte zu speichern.
const upload = multer({
    storage: storage,
    limits: {
        fileSize: 2097152,
    },
});

app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.post("/submit-form", upload.single("image"), (req, res) => {
    const formData = req.body;
    const uploadedFile = req.file;

    console.log("Form data: ", formData);
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
