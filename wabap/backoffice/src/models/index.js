// @ts-check
import { initSchema } from '@aws-amplify/datastore';
import { schema } from './schema';

const Status = {
  "PENDING": "PENDING",
  "IN_PROGRESS": "IN_PROGRESS",
  "ISSUE": "ISSUE",
  "COMPLETED": "COMPLETED"
};

const { Subscriber, Mission, Inscription, Tournee, Colis, ColisStatus, Location } = initSchema(schema);

export {
  Subscriber,
  Mission,
  Inscription,
  Tournee,
  Colis,
  ColisStatus,
  Location,
  Status
};