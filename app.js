const TOTAL_BINS = 42;

let currentBin = null;

let storageData =
    JSON.parse(localStorage.getItem("storageData")) || {};

const shelfGrid = document.getElementById("shelfGrid");
const editor = document.getElementById("editor");
const binTitle = document.getElementById("binTitle");
const binName = document.getElementById("binName");
const binContents = document.getElementById("binContents");
const updated = document.getElementById("updated");

function saveData() {
    localStorage.setItem(
        "storageData",
        JSON.stringify(storageData)
    );
}

function renderBins(filter = "") {

    shelfGrid.innerHTML = "";

    for (let i = 1; i <= TOTAL_BINS; i++) {

        const id = `BIN${String(i).padStart(2, "0")}`;

        if (!storageData[id]) {
            storageData[id] = {
                name: "",
                contents: "",
                updated: ""
            };
        }

        const bin = storageData[id];

        const searchText =
            (bin.name + " " + bin.contents).toLowerCase();

        if (
            filter &&
            !searchText.includes(filter.toLowerCase())
        ) {
            continue;
        }

        const div = document.createElement("div");
        div.className = "bin";

        div.innerHTML = `
            <strong>${id}</strong>
            <div class="bin-name">
                ${bin.name || "Empty"}
            </div>
        `;

        div.onclick = () => openBin(id);

        shelfGrid.appendChild(div);
    }
}

function openBin(id) {

    currentBin = id;

    const bin = storageData[id];

    editor.classList.remove("hidden");

    binTitle.textContent = id;

    binName.value = bin.name || "";
    binContents.value = bin.contents || "";

    updated.textContent =
        bin.updated
        ? `Last Updated: ${bin.updated}`
        : "Never Updated";
}

document
.getElementById("saveBtn")
.addEventListener("click", () => {

    storageData[currentBin] = {
        name: binName.value,
        contents: binContents.value,
        updated: new Date().toLocaleString()
    };

    saveData();
    renderBins();

    updated.textContent =
        `Last Updated: ${storageData[currentBin].updated}`;

    alert("Saved!");
});

document
.getElementById("search")
.addEventListener("input", e => {
    renderBins(e.target.value);
});

renderBins();
