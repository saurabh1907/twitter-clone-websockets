
import {Socket} from "phoenix"


let socket = new Socket("/socket", {params: {token: window.userToken}})
socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("twitter", {})
// Now that you are connected, you can join channels with a topic:


document.addEventListener("DOMContentLoaded", function(){
  // Handler when the DOM is fully loaded
  console.log("joining channel")
  channel.push('request', {data: "dummy"});
});


channel.on("output", payload => {
  console.log(payload)
});

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket

