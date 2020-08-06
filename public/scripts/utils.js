export const errorMessages = {
    "invalid_pwd" : "Password must contain 8 characters, one uppercase, one lowercase, one symbol of @?!* and one digit",
    "invalid_email": "Your Email in invalid",
    "non_matching_pwds": "The two password you typed are not identical",
    "duplicate_username": "Sorry, this username is already in use",
    "duplicate_email": "Sorry, there is already an account registered with this email",
}

export function ajaxify(jsonString, callback, route) {
    var httpRequest = new XMLHttpRequest();
    httpRequest.onreadystatechange = function() {
        if (httpRequest.readyState === 4 && httpRequest.status !== 200) {
            console.log('error return requete serveur')
            document.write(httpRequest.status)
            return false
        }
        else if (httpRequest.readyState === 4 && httpRequest.status === 200) {
            var httpResponse = httpRequest.response
            if (httpResponse) {
                var obj = JSON.parse(httpRequest.response)
                if (obj) {
                    callback(obj)
                }
            }
        }
    }
    httpRequest.open('POST', route, true)
    httpRequest.setRequestHeader('Content-Type', 'multipart/form-data')
    httpRequest.send(jsonString)
}

export function notifyUser(status, message) {
    var notificationList = document.getElementById("notificationList")

    var notification = document.createElement("div")
    notification.innerHTML = message
    switch (status) {
        case "success":
            notification.style.backgroundColor = "green"
            break
        case "error":
            notification.style.backgroundColor = "red"
            break
    }
    notificationList.appendChild(notification)
    setTimeout(() => {
        notification.remove()
    }, 6000);
}

export function openModal(modalName) {
    var button = document.getElementById("button-" + modalName)
    var modal = document.getElementById("modal-" + modalName)

    button.onclick = () => {
        modal.classList.add('is-active')
    }
}

export function closeModal(modalName) {
    document.getElementById("modal-" + modalName).classList.remove('is-active')
}

export function goToHome() {
    document.location.href = '/index.php'
}