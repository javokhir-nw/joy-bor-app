const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendChatNotification = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const chatId = event.params.chatId;

    // Chat ma'lumotlarini olish
    const chatDoc = await admin.firestore()
      .collection("chats")
      .doc(chatId)
      .get();

    if (!chatDoc.exists) return null;

    const chat = chatDoc.data();
    const senderId = message.senderId;
    const participants = chat.participants;

    // Receiver
    const receiverUid = participants.find(uid => uid !== senderId);
    if (!receiverUid) return null;

    // Receiver token
    const receiverDoc = await admin.firestore()
      .collection("users")
      .doc(receiverUid)
      .get();

    if (!receiverDoc.exists) return null;

    const receiverToken = receiverDoc.data().fcmToken;
    if (!receiverToken) return null;

    // Sender ismi
    const senderDoc = await admin.firestore()
      .collection("users")
      .doc(senderId)
      .get();

    const senderName = senderDoc.data()?.displayName ?? "Kimdir";

    // Notification yuborish
    try {
      await admin.messaging().send({
        token: receiverToken,
        notification: {
          title: senderName,
          body: message.text,
        },
        data: {
          chatId: chatId,
          type: "chat",
        },
      });
      console.log("Notification yuborildi:", receiverUid);
    } catch (e) {
      console.error("Xato:", e);
    }

    return null;
  }
);