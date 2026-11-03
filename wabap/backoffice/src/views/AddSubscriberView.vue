<script>
export default {
  data() {
    return {
      abonnes: [
        // Liste d'exemple d'abonnés
        
      ],
      optionsSecteur: ["P11", "P12", "P01", "Aucun"],
    };
  },
  methods: {
    ajouterAbonne() {
      this.abonnes.push({ selectionne: false, nom: "", adresse: "", complement_adresse: "", boite_postale: "", ville_code_postale: "", num_portable: "", num_fixe: "", secteur: "Aucun", gps: "" });
    },
    supprimerAbonne(index) {
      this.abonnes.splice(index, 1);
    },
    importerCSV() {
      alert("Importer CSV abonnés - Non implémenté");
    },
    handleFileUpload(event) {
  const file = event.target.files[0];
  if (file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      const csvContent = e.target.result;
      const lines = csvContent.split('\n');
      const headers = lines[0].split('|').map((header) => header.trim()); 
      for (let i = 1; i < lines.length; i++) {
        const values = lines[i].split('|').map((value) => value.trim()); 
        if (values.length === headers.length) {
          const abonne = {
            selectionne: true,
            titre: values[headers.indexOf('TITRE')],
            no_parution: values[headers.indexOf('NO_PARUTION')],
            date: values[headers.indexOf('DATE')],
            vol_1: values[headers.indexOf('VOL1')], 
            nom: values[headers.indexOf('NOM_ABO')], 
            adresse: values[headers.indexOf('VOL2')],
            complement_adresse: values[headers.indexOf('VOL3')],
            boite_postale: values[headers.indexOf('VOL4')],
            ville_code_postale: values[headers.indexOf('VOL6')],
            vol_5: values[headers.indexOf('VOL5')],
            noabo: values[headers.indexOf("NOABO")],
            num_portable: values[headers.indexOf('TEL_POR')],
            num_fixe: values[headers.indexOf('TEL_FIXE')],
            secteur: values[headers.indexOf('SECTEUR')],
            nom_porteur: values[headers.indexOf('NOM_PORTEUR')],
            consigne_liv: values[headers.indexOf('CONSIGNE_LIV')],
            gps: values[headers.indexOf('GPS')],
            qte: values[headers.indexOf('QTE')],
          };
          this.abonnes.push(abonne);
        }
      }
    };
    reader.readAsText(file);
  }
},


    telechargerTXT() {
      const abonnesCoches = this.abonnes.filter((abonne) => abonne.selectionne);
      let contenu = "TITRE|NO_PARUTION|DATE|VOL1|VOL2|VOL3|VOL4|VOL5|VOL6|NOABO|TEL_FIXE|TEL_POR|SECTEUR|NOM_PORTEUR|CONSIGNE_LIV|GPS|QTE|NOM_ABO\n";
      abonnesCoches.forEach((abonne) => {
        contenu += `${abonne.titre}|${abonne.no_parution}|${abonne.date}|${abonne.vol_1 ? abonne.nom : ""}|${abonne.adresse}|${abonne.complement_adresse}|${abonne.boite_postale}|${abonne.vol_5}|${abonne.ville_code_postale}|${abonne.noabo}|${abonne.num_fixe}|${abonne.num_portable}|${abonne.secteur}|${abonne.nom_porteur}|${abonne.consigne_liv}|${abonne.gps}|${abonne.qte}|${abonne.nom ? abonne.nom : abonne.adresse }\n`;
      });
      if (abonnesCoches.length === 0) {
        alert("Aucun abonné sélectionné.");
        return;
      }
      const blob = new Blob([contenu], { type: "text/plain;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const lien = document.createElement("a");
      lien.href = url;
      lien.download = "abonnes_selectionnes.txt";
      lien.click();
      URL.revokeObjectURL(url);
    },
    sauvegarder() {
      alert("Sauvegarder - Non implémenté");
    },
  },
};
</script>

<style scoped>
.editeur {
  padding: 20px;
  font-family: Arial, sans-serif;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.title {
  margin: 0;
  font-size: 2.5em;
  font-weight: bold;
}

.table-responsive {
  overflow-x: auto;
  max-width: 100%;
}


table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  border: 1px solid #ddd;
  padding: 8px;
  text-align: left;
  white-space: nowrap;
}

th {
  background-color: #f2f2f2;
}

th.th-small {
  width: 5vw;
}

.input-small {
  width: 100%;
}

.fixed-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  width: 100%;
  background-color: #fff;
  border-top: 1px solid #ddd;
  padding: 10px 80px;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 5px; /* Reduce gap to bring buttons closer */
  box-shadow: 0 -2px 5px rgba(0, 0, 0, 0.1);
  z-index: 1000; /* Ajoutez un z-index élevé pour s'assurer que la barre est au-dessus du menu */
}

.button-primary {
  background-color: #FE9D01;
  color: white;
  border: none;
  padding: 10px 15px;
  cursor: pointer;
  border-radius: 4px;
  margin-left: 5vw; /* Ajoute une marge gauche spécifique au bouton "Sauvegarder" */
  font-size: 1.5em;
}

.button-primary:hover {
  background-color: #D88001;
}

.button-secondary {
  background-color: #022949;
  color: white;
  border: none;
  padding: 10px 15px;
  cursor: pointer;
  border-radius: 4px;
  font-size: 1.5em;
}

.button-secondary:hover {
  background-color: #034E6C;
}

.button-danger {
  background-color: #dc3545;
  color: white;
  border: none;
  padding: 5px 10px;
  cursor: pointer;
  border-radius: 4px;
}

.button-danger:hover {
  background-color: #bd2130;
}
</style>


<template>
  <div class="editeur">
    <!-- Titre et bouton import -->
    <div class="header">
      <h2 class="title">Éditer les Abonnés</h2>
      <div>
        <!-- Bouton pour déclencher l'import -->
        <input
          type="file"
          ref="fileInput"
          @change="handleFileUpload"
          accept=".txt"
          style="display: none;"
        />
        <button
          class="button-primary"
          @click="$refs.fileInput.click()"
        >
          Importer CSV abonnés
        </button>
      </div>
    </div>

    <!-- Tableau des abonnés -->
    <div class="table-responsive">
      <table>
        <thead>
          <tr>
            <th>Abo</th>
            <th>Nom</th>
            <th>Adresse</th>
            <th class="th-small">Complément adresse</th>
            <th>CP & Ville</th>
            <th class="th-small">NOABO </th>
            <th class="th-small">Portable</th>
            <th class="th-small">Fixe</th>
            <th class="th-small">Secteur</th>
            <th class="th-small">Consigne Liv</th>
            <th class="th-small">QTE</th>
            <th>GPS</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(abonne, index) in abonnes" :key="index">
            <td><input type="checkbox" v-model="abonne.selectionne" /></td>
            <td><input type="text" v-model="abonne.nom" /></td>
            <td><input type="text" v-model="abonne.boite_postale" /></td>
            <td><input type="text" v-model="abonne.complement_adresse" class="input-small" /></td>
            <td><input type="text" v-model="abonne.ville_code_postale" /></td>
            <td><input type="text" v-model="abonne.noabo" class="input-small"/></td>
            <td><input type="text" v-model="abonne.num_portable" class="input-small" /></td>
            <td><input type="text" v-model="abonne.num_fixe" class="input-small" /></td>
            <td><input type="text" v-model="abonne.secteur" class="input-small" /></td>
            <td><input type="text" v-model="abonne.consigne_liv" class="input-small" /></td>
            <td><input type="text" v-model="abonne.qte"  class="input-small"/></td>
            <td><input type="text" v-model="abonne.gps"  /></td>
            <td><button class="button-danger" @click="supprimerAbonne(index)">🗑️</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Boutons fixes en bas de la page -->
    <div class="fixed-actions">
      <button @click="ajouterAbonne" class="button-secondary">Ajouter un nouvel abonné</button>
      <button @click="telechargerTXT" class="button-secondary">Télécharger TXT</button>
    </div>
  </div>
</template>



