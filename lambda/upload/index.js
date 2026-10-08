import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import Busboy from "busboy";
import { v4 as uuidv4 } from "uuid";

const s3 = new S3Client({});

/**
 * Helper – valida que el Content‑Type sea una imagen aceptada.
 */
function isSupportedImage(contentType) {
  const allowed = ["image/jpeg", "image/png", "image/gif", "image/webp"];
  return allowed.includes(contentType.toLowerCase());
}


// Lambda handler (Node 20, ES‑modules)

export const handler = async (event) => {
  try {

    // 1  Se recuperan encabezados y se valida Content‑Type

    const headers = event.headers ?? {};
    const contentType =
      headers["content-type"] || headers["Content-Type"] || "";
    if (!contentType) throw new Error("Missing Content-Type header");

    if (!isSupportedImage(contentType)) {
      throw new Error(`Unsupported Media Type: ${contentType}`);
    }


    // 2  Caso base64 (payload esBinary=true) – útil para pruebas con Postman

    if (event.isBase64Encoded) {
      const body = Buffer.from(event.body, "base64");
      const ext = contentType.split("/")[1]; // jpg / png / …
      const key = `${process.env.UPLOAD_PREFIX}${uuidv4()}.${ext}`;

      await s3.send(
        new PutObjectCommand({
          Bucket: process.env.BUCKET,
          Key: key,
          Body: body,
          ContentType: contentType,
        })
      );

      return {
        statusCode: 201,
        body: JSON.stringify({ message: "uploaded", key }),
      };
    }

    // 3  Caso multipart/form‑data (usado desde navegadores / UI)

    // API Gateway entrega el cuerpo como base64, por lo que se convierte a Buffer
    const rawBody = Buffer.from(event.body, "base64");

    return new Promise((resolve, reject) => {
      const busboy = Busboy({
        headers: { "content-type": contentType },
        limits: { fileSize: 10 * 1024 * 1024 }
      });
      let uploadedKey = null;

      busboy.on(
        "file",
        (fieldname, file, filename, encoding, mimetype) => {
          // Se guarda el buffer completo en memory (tamaño max 10 MB → OK para Lambda)
          const chunks = [];

          file.on("data", (data) => chunks.push(data));

          file.on("end", async () => {
            const buffer = Buffer.concat(chunks);
            const ext = mimetype.split("/")[1];
            uploadedKey = `${process.env.UPLOAD_PREFIX}${uuidv4()}.${ext}`;

            try {
              await s3.send(
                new PutObjectCommand({
                  Bucket: process.env.BUCKET,
                  Key: uploadedKey,
                  Body: buffer,
                  ContentType: mimetype,
                })
              );
            } catch (e) {
              reject(e);
            }
          });
        }
      );

      busboy.on("finish", () => {
        resolve({
          statusCode: 201,
          body: JSON.stringify({ message: "uploaded", key: uploadedKey }),
        });
      });

      busboy.on("error", (err) => reject(err));

      // Se alimenta busboy con el cuerpo binario ya convertido a Buffer
      busboy.end(rawBody);
    });
  } catch (error) {
    console.error("Upload Lambda error:", error);
    return {
      statusCode: 400,
      body: JSON.stringify({ error: error.message }),
    };
  }
};


