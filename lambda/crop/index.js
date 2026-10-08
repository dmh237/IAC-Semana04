import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import sharp from "sharp";


// Configuración del cliente S3 (usa la configuración del entorno de Lambda)

const s3 = new S3Client({});

/**
 * Convierte un ReadableStream (que devuelve S3) a un Buffer.
 * Necesario porque Sharp trabaja con Buffer o con Path de archivo.
 */
const streamToBuffer = (stream) =>
  new Promise((resolve, reject) => {
    const chunks = [];
    stream.on("data", (chunk) => chunks.push(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(Buffer.concat(chunks)));
  });

/**
 * Crea una máscara SVG circular de 40 px de diámetro.
 * Utilizamos la opción `blend: 'dest-in'` de Sharp para recortar la
 * imagen conservando la transparencia fuera del círculo.
 */
const circleMask = Buffer.from(
  `<svg width="40" height="40"><circle cx="20" cy="20" r="20" fill="white"/></svg>`
);

/**
 * Lambda handler (SQS batch).  El atributo **reportBatchItemFailures**
 * permite devolver sólo los mensajes que fallaron.
 */
export const handler = async (event) => {
  const batchItemFailures = [];

  for (const record of event.Records) {
    const receiptHandle = record.receiptHandle; // necesario para reportar fallo


    // 1  El cuerpo del mensaje SQS es el *evento S3* generado por la
    //     notificación de ObjectCreated.  Extraemos el `key` del objeto.

    let s3Key;
    try {
      const body = JSON.parse(record.body);
      // El formato de notificación es: body.Records[0].s3.object.key
      s3Key = decodeURIComponent(
        body?.Records?.[0]?.s3?.object?.key?.replace(/\+/g, " ")
      );
      if (!s3Key) throw new Error("Key not found in S3 event");
    } catch (e) {
      console.error("Failed to parse SQS message:", e);
      batchItemFailures.push({ itemIdentifier: receiptHandle });
      continue;
    }

    // 2  Se descarga la imagen original desde S3 (uploads/)

    let originalBuffer;
    try {
      const getResp = await s3.send(
        new GetObjectCommand({
          Bucket: process.env.BUCKET,
          Key: s3Key,
        })
      );
      originalBuffer = await streamToBuffer(getResp.Body);
    } catch (e) {
      console.error(`Error getting object ${s3Key} from S3:`, e);
      batchItemFailures.push({ itemIdentifier: receiptHandle });
      continue;
    }

    // 3  Se recorta + máscara circular → PNG 40×40 con fondo transparente

    let processedBuffer;
    try {
      processedBuffer = await sharp(originalBuffer)
        .resize(40, 40, { fit: "cover" }) // recorta manteniendo aspecto
        .composite([{ input: circleMask, blend: "dest-in" }]) // máscara circular
        .png()
        .toBuffer();
    } catch (e) {
      console.error(`Sharp processing failed for ${s3Key}:`, e);
      batchItemFailures.push({ itemIdentifier: receiptHandle });
      continue;
    }


    // 4  Se cosntruye el nombre del nuevo objeto: *original‑name_circular.png*

    const filename = s3Key.split("/").pop(); // solo el nombre con extensión
    const nameWithoutExt = filename.replace(/\.[^.]+$/, ""); // elimina extensión
    const destKey = `${process.env.PROCESSED_PREFIX}${nameWithoutExt}_circular.png`;

    // 5  Se sube el PNG recortado a S3 (processed/)

    try {
      await s3.send(
        new PutObjectCommand({
          Bucket: process.env.BUCKET,
          Key: destKey,
          Body: processedBuffer,
          ContentType: "image/png",
        })
      );
      console.log(`Successfully processed ${s3Key} → ${destKey}`);
    } catch (e) {
      console.error(`Error putting processed object ${destKey}:`, e);
      batchItemFailures.push({ itemIdentifier: receiptHandle });
    }
  }

  // 6  Se devuelve sólo los mensajes que fallaron (SQS los re‑intenta)

  return { batchItemFailures };
};