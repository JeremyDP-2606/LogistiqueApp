export async function sleep(time) {
  await new Promise((resolve) => setTimeout(resolve, time));
}

export function isFloat(str) {
  return !isNaN(str) && !isNaN(parseFloat(str));
}

export function getAttribute(user, attributeName, defaultValue = "") {
  if (user === null || user === undefined) return defaultValue;
  const attribute = user.Attributes.find((attr) => attr.Name === attributeName);
  return attribute ? attribute.Value : defaultValue;
}

export function isAttribute(user, attributeName) {
  if (user === null || user === undefined) return false;
  const attribute = user.Attributes.find((attr) => attr.Name === attributeName);
  return !!attribute;
}

export function formatHeure(time) {
  if (time == undefined) return "";
  const h = Math.trunc(time);
  const m = Math.round((time - Math.trunc(time)) * 60);
  return (h < 10 ? "0" + h : h) + "h" + (m < 10 ? "0" + m : m);
}

export function formatLivreurName(
  livreur,
  defaultValue = livreur?.Username || "no_name"
) {
  if (isAttribute(livreur, "given_name") && isAttribute(livreur, "given_name"))
    return (
      getAttribute(livreur, "given_name") +
      " " +
      getAttribute(livreur, "family_name")
    );
  else return defaultValue;
}
export function statusColor(status) {
  if (status == "PENDING") return "orange";
  if (status == "IN_PROGRESS") return "blue";
  if (status == "ISSUE") return "red";
  if (status == "COMPLETED") return "green";
  if (status == "NOT_PICKED_UP_NOT_EXIST") return "orange"
  return "grey";
}
export function statusName(status) {
  if (status == "PENDING") return "En attente";
  if (status == "IN_PROGRESS") return "En cours";
  if (status == "ISSUE") return "Incident";
  if (status == "COMPLETED") return "Accomplie";
  if (status == "NOT_PICKED_UP_NOT_EXIST") return "Non récupéré"
  return status;
}

export function formatDuration(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds - hours * 3600) / 60);
  const remainingSeconds = seconds - hours * 3600 - minutes * 60;
  let result = "";
  if (hours > 0) {
    result += hours + "h ";
  }
  if (minutes > 0 || hours > 0) {
    result += minutes + "m ";
  }
  result += remainingSeconds + "s";
  return result.trim();
}
export function formatDistance(m) {
  if (m > 1000) return Math.round(m / 10) / 100 + " km";
  else return Math.round(m) + " m";
}

export function formatDateTournee(dateString) {
  try {
    const date = new Date(dateString);
    const options = {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    };
    return new Intl.DateTimeFormat("fr-FR", options).format(date);
  } catch (error) {
    return dateString;
  }
}

export function nbColisByStatus(colis, status) {
  return (
    colis?.filter((colis) => colis?.lastStatus.status === status).length || 0
  );
}
export function formatCoordonne(c) {
  return c ? c.toPrecision(8) : c;
}
export function formatCoordonnes(lat, lng) {
  return formatCoordonne(lat) + ", " + formatCoordonne(lng);
}

export function formatError(error) {
  if (error.errors) {
    return error.errors.map((e) => e.message).join(" | ");
  } else if (error.message) {
    return error.message;
  } else if (error.code) {
    return error.code;
  }
  return JSON.stringify(error);
}

import moment from "moment";
import "moment/dist/locale/fr";
export function formatDateTimeTournee(dateString) {
  moment.locale("fr");
  return moment(dateString).format("dddd D MMMM YYYY [à] HH[h]mm");
}

export function formatDateTime(dateString) {
  return moment(dateString).format("DD/MM/YYYY [à] HH[h]mm[m]ss[s]");
}

export const toBase64 = file => new Promise((resolve, reject) => {
  const reader = new FileReader();
  reader.readAsDataURL(file);
  reader.onload = () => resolve(reader.result);
  reader.onerror = error => reject(error);
});

export function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}