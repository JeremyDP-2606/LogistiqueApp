/* eslint-disable no-undef */
/* Amplify Params - DO NOT EDIT
	API_WABAP_GRAPHQLAPIENDPOINTOUTPUT
	API_WABAP_GRAPHQLAPIIDOUTPUT
	ENV
	REGION
Amplify Params - DO NOT EDIT */

const AWS = require('aws-sdk');
const PDFDocument = require('pdfkit');
const docClient = new AWS.DynamoDB.DocumentClient();

// Fonction pour générer un PDF
function generatePdf(tourneeData) {
    const doc = new PDFDocument();
    const chunks = [];
    
    doc.text(`Rapport de la tournée : ${tourneeData.tournee_id.S}`);
    doc.text(`Date : ${tourneeData.date.S}`);
    doc.text('Colis :');
    
    doc.end();
    
    // Convertir le flux en buffer
    return new Promise((resolve, reject) => {
        doc.on('data', (chunk) => chunks.push(chunk));
        doc.on('end', () => resolve(Buffer.concat(chunks)));
        doc.on('error', reject);
    });
}

// Fonction pour envoyer un email avec le PDF en pièce jointe
async function sendEmailWithPdf(email, pdfBuffer, tourneeId) {
    const params = {
        Source: process.env.SENDER_EMAIL, // Adresse email de l'expéditeur
        Destination: {
            ToAddresses: [email], // Adresse email du destinataire
        },
        Message: {
            Subject: {
                Data: `Rapport de la tournée ${tourneeId}`,
            },
            Body: {
                Text: {
                    Data: `Veuillez trouver ci-joint le rapport de la tournée ${tourneeId}.`,
                },
            },
        },
        RawMessage: {
            Data: `From: ${process.env.SENDER_EMAIL}\nTo: ${email}\nSubject: Rapport de la tournée ${tourneeId}\nMIME-Version: 1.0\nContent-Type: multipart/mixed; boundary="NextPart"\n\n--NextPart\nContent-Type: text/plain\n\nVeuillez trouver ci-joint le rapport de la tournée ${tourneeId}.\n\n--NextPart\nContent-Type: application/pdf\nContent-Disposition: attachment; filename="rapport_tournee_${tourneeId}.pdf"\n\n${pdfBuffer.toString('base64')}\n\n--NextPart--`,
        },
    };

    try {
        const response = await ses.sendRawEmail(params).promise();
        return response;
    } catch (error) {
        console.error('Erreur lors de l\'envoi de l\'email :', error);
        throw error;
    }
}

// Handler de la fonction Lambda
exports.handler = async (event) => {
    const tourneeId = event.tournee_id;
    const email = event.email;

    try {
        // Récupérer les données de la tournée depuis DynamoDB
        const tournee = await docClient
        .scan({
          TableName: `Tournee-${process.env.API_WABAP_GRAPHQLAPIIDOUTPUT}-${process.env.ENV}`,
          Limit: 100,
          ExclusiveStartKey: exclusiveStartKey,
          FilterExpression: "#i = :i",
          ExpressionAttributeValues: {
            ":i": tourneeId,
          },
          ExpressionAttributeNames: { "#i": "id" },
        })
        .promise();

        if (!tournee.Item) {
            return {
                statusCode: 404,
                body: JSON.stringify('Tournée non trouvée'),
            };
        }

        const tourneeData = tournee.Item;

        // Générer le PDF
        const pdfBuffer = await generatePdf(tourneeData);

        // Envoyer le PDF par email
        await sendEmailWithPdf(email, pdfBuffer, tourneeId);

        return {
            statusCode: 200,
            body: JSON.stringify('Rapport envoyé avec succès'),
        };
    } catch (error) {
        console.error('Erreur :', error);
        return {
            statusCode: 500,
            body: JSON.stringify('Erreur lors du traitement de la demande'),
        };
    }
};