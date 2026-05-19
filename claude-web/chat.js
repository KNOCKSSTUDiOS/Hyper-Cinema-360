const API_KEY = "YOUR_CLAUDE_API_KEY";

async function sendMessage(text) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json"
    },
    body: JSON.stringify({
      model: "claude-3-opus-20240229",
      messages: [{ role: "user", content: text }]
    })
  });

  const data = await res.json();
  return data.content[0].text;
}

const chat = document.getElementById("chat");
const input = document.getElementById("msg");

input.addEventListener("keydown", async (e) => {
  if (e.key === "Enter") {
    const text = input.value;
    input.value = "";
    chat.innerHTML += `<div><b>You:</b> ${text}</div>`;
    const reply = await sendMessage(text);
    chat.innerHTML += `<div><b>Claude:</b> ${reply}</div>`;
    chat.scrollTop = chat.scrollHeight;
  }
});
