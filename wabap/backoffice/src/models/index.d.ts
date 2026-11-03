import { ModelInit, MutableModel, __modelMeta__, ManagedIdentifier } from "@aws-amplify/datastore";
// @ts-ignore
import { LazyLoading, LazyLoadingDisabled, AsyncItem, AsyncCollection } from "@aws-amplify/datastore";

export enum Status {
  PENDING = "PENDING",
  IN_PROGRESS = "IN_PROGRESS",
  ISSUE = "ISSUE",
  COMPLETED = "COMPLETED"
}



type EagerSubscriber = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Subscriber, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner: string;
  readonly name: string;
  readonly address?: string | null;
  readonly numabo?: string | null;
  readonly secteur?: string | null;
  readonly phone1?: string | null;
  readonly phone2?: string | null;
  readonly instructions?: string | null;
  readonly longitude?: number | null;
  readonly latitude?: number | null;
  readonly mission?: Mission | null;
  readonly colis?: (Colis | null)[] | null;
  readonly type: string;
  readonly nb: number;
  readonly unsubscribed?: boolean | null;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
  readonly missionSubscribersId?: string | null;
}

type LazySubscriber = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Subscriber, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner: string;
  readonly name: string;
  readonly address?: string | null;
  readonly numabo?: string | null;
  readonly secteur?: string | null;
  readonly phone1?: string | null;
  readonly phone2?: string | null;
  readonly instructions?: string | null;
  readonly longitude?: number | null;
  readonly latitude?: number | null;
  readonly mission: AsyncItem<Mission | undefined>;
  readonly colis: AsyncCollection<Colis>;
  readonly type: string;
  readonly nb: number;
  readonly unsubscribed?: boolean | null;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
  readonly missionSubscribersId?: string | null;
}

export declare type Subscriber = LazyLoading extends LazyLoadingDisabled ? EagerSubscriber : LazySubscriber

export declare const Subscriber: (new (init: ModelInit<Subscriber>) => Subscriber) & {
  copyOf(source: Subscriber, mutator: (draft: MutableModel<Subscriber>) => MutableModel<Subscriber> | void): Subscriber;
}

type EagerMission = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Mission, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner: string;
  readonly name: string;
  readonly subscribers?: (Subscriber | null)[] | null;
  readonly livreurID: string;
  readonly inscriptions?: (Inscription | null)[] | null;
  readonly startName?: string | null;
  readonly startLongitude: number;
  readonly startLatitude: number;
  readonly daysOfWeek?: boolean[] | null;
  readonly generateDayBefore?: boolean | null;
  readonly startTime?: number | null;
  readonly startTimeZone?: string | null;
  readonly tournee?: (Tournee | null)[] | null;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

type LazyMission = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Mission, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner: string;
  readonly name: string;
  readonly subscribers: AsyncCollection<Subscriber>;
  readonly livreurID: string;
  readonly inscriptions: AsyncCollection<Inscription>;
  readonly startName?: string | null;
  readonly startLongitude: number;
  readonly startLatitude: number;
  readonly daysOfWeek?: boolean[] | null;
  readonly generateDayBefore?: boolean | null;
  readonly startTime?: number | null;
  readonly startTimeZone?: string | null;
  readonly tournee: AsyncCollection<Tournee>;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

export declare type Mission = LazyLoading extends LazyLoadingDisabled ? EagerMission : LazyMission

export declare const Mission: (new (init: ModelInit<Mission>) => Mission) & {
  copyOf(source: Mission, mutator: (draft: MutableModel<Mission>) => MutableModel<Mission> | void): Mission;
}

type EagerInscription = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Inscription, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly mission?: Mission | null;
  readonly livreurID: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
  readonly missionInscriptionsId?: string | null;
}

type LazyInscription = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Inscription, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly mission: AsyncItem<Mission | undefined>;
  readonly livreurID: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
  readonly missionInscriptionsId?: string | null;
}

export declare type Inscription = LazyLoading extends LazyLoadingDisabled ? EagerInscription : LazyInscription

export declare const Inscription: (new (init: ModelInit<Inscription>) => Inscription) & {
  copyOf(source: Inscription, mutator: (draft: MutableModel<Inscription>) => MutableModel<Inscription> | void): Inscription;
}

type EagerTournee = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Tournee, 'id'>;
    readOnlyFields: 'updatedAt';
  };
  readonly id: string;
  readonly owner: string;
  readonly name: string;
  readonly status: Status | keyof typeof Status;
  readonly colis: Colis[];
  readonly startName?: string | null;
  readonly startLongitude: number;
  readonly startLatitude: number;
  readonly livreurID: string;
  readonly missionTourneeId: string;
  readonly mission: Mission;
  readonly createdAt: string;
  readonly distance?: number | null;
  readonly duree?: number | null;
  readonly nbColis?: number | null;
  readonly updatedAt?: string | null;
}

type LazyTournee = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Tournee, 'id'>;
    readOnlyFields: 'updatedAt';
  };
  readonly id: string;
  readonly owner: string;
  readonly name: string;
  readonly status: Status | keyof typeof Status;
  readonly colis: AsyncCollection<Colis>;
  readonly startName?: string | null;
  readonly startLongitude: number;
  readonly startLatitude: number;
  readonly livreurID: string;
  readonly missionTourneeId: string;
  readonly mission: AsyncItem<Mission>;
  readonly createdAt: string;
  readonly distance?: number | null;
  readonly duree?: number | null;
  readonly nbColis?: number | null;
  readonly updatedAt?: string | null;
}

export declare type Tournee = LazyLoading extends LazyLoadingDisabled ? EagerTournee : LazyTournee

export declare const Tournee: (new (init: ModelInit<Tournee>) => Tournee) & {
  copyOf(source: Tournee, mutator: (draft: MutableModel<Tournee>) => MutableModel<Tournee> | void): Tournee;
}

type EagerColis = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Colis, 'id'>;
    readOnlyFields: 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly tournee: Tournee;
  readonly tourneeColisId: string;
  readonly subscriber?: Subscriber | null;
  readonly subscriberColisId?: string | null;
  readonly createdAt: string;
  readonly position: number;
  readonly polyline?: string | null;
  readonly distance?: number | null;
  readonly duration?: number | null;
  readonly address: string;
  readonly longitude: number;
  readonly latitude: number;
  readonly subscriberName: string;
  readonly lastStatus: ColisStatus;
  readonly logs: ColisStatus[];
  readonly updatedAt?: string | null;
  readonly colisLastStatusId: string;
}

type LazyColis = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Colis, 'id'>;
    readOnlyFields: 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly tournee: AsyncItem<Tournee>;
  readonly tourneeColisId: string;
  readonly subscriber: AsyncItem<Subscriber | undefined>;
  readonly subscriberColisId?: string | null;
  readonly createdAt: string;
  readonly position: number;
  readonly polyline?: string | null;
  readonly distance?: number | null;
  readonly duration?: number | null;
  readonly address: string;
  readonly longitude: number;
  readonly latitude: number;
  readonly subscriberName: string;
  readonly lastStatus: AsyncItem<ColisStatus>;
  readonly logs: AsyncCollection<ColisStatus>;
  readonly updatedAt?: string | null;
  readonly colisLastStatusId: string;
}

export declare type Colis = LazyLoading extends LazyLoadingDisabled ? EagerColis : LazyColis

export declare const Colis: (new (init: ModelInit<Colis>) => Colis) & {
  copyOf(source: Colis, mutator: (draft: MutableModel<Colis>) => MutableModel<Colis> | void): Colis;
}

type EagerColisStatus = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<ColisStatus, 'id'>;
    readOnlyFields: 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly colis?: Colis | null;
  readonly colisLogsId: string;
  readonly status: Status | keyof typeof Status;
  readonly message?: string | null;
  readonly createdAt: string;
  readonly longitude?: number | null;
  readonly latitude?: number | null;
  readonly updatedAt?: string | null;
}

type LazyColisStatus = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<ColisStatus, 'id'>;
    readOnlyFields: 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly colis: AsyncItem<Colis | undefined>;
  readonly colisLogsId: string;
  readonly status: Status | keyof typeof Status;
  readonly message?: string | null;
  readonly createdAt: string;
  readonly longitude?: number | null;
  readonly latitude?: number | null;
  readonly updatedAt?: string | null;
}

export declare type ColisStatus = LazyLoading extends LazyLoadingDisabled ? EagerColisStatus : LazyColisStatus

export declare const ColisStatus: (new (init: ModelInit<ColisStatus>) => ColisStatus) & {
  copyOf(source: ColisStatus, mutator: (draft: MutableModel<ColisStatus>) => MutableModel<ColisStatus> | void): ColisStatus;
}

type EagerLocation = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Location, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly userId: string;
  readonly userName?: string | null;
  readonly tourneeId: string;
  readonly latitude: number;
  readonly longitude: number;
  readonly lastUpdate: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

type LazyLocation = {
  readonly [__modelMeta__]: {
    identifier: ManagedIdentifier<Location, 'id'>;
    readOnlyFields: 'createdAt' | 'updatedAt';
  };
  readonly id: string;
  readonly owner?: string | null;
  readonly userId: string;
  readonly userName?: string | null;
  readonly tourneeId: string;
  readonly latitude: number;
  readonly longitude: number;
  readonly lastUpdate: string;
  readonly createdAt?: string | null;
  readonly updatedAt?: string | null;
}

export declare type Location = LazyLoading extends LazyLoadingDisabled ? EagerLocation : LazyLocation

export declare const Location: (new (init: ModelInit<Location>) => Location) & {
  copyOf(source: Location, mutator: (draft: MutableModel<Location>) => MutableModel<Location> | void): Location;
}