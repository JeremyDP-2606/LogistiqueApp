
import config from "../aws-exports";


export const color = { primary: "#ff9500",  secondary: "#f26f00", text_second: "#A0A0A0", green_light: "#A5D6A7", green: "#4CAF50" };
export const ENV = config.aws_cloud_logic_custom[0].endpoint.split('/').pop();//TODO : fix
export const MARTINIQUE = { lat: 14.64, lng: -61.02 };
