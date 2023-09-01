import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import multer from "multer";

const app = express();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

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
    } else {
        console.log("No file uploaded");
    }

    res.send("Form data received successfully.");
});

app.listen(3000, () => {
    console.log("Server läuft auf Port 3000");
});
