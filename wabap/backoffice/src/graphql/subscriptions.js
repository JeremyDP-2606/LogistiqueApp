/* eslint-disable */
// this is an auto generated file. This will be overwritten

export const onCreateSubscriber = /* GraphQL */ `
  subscription OnCreateSubscriber(
    $filter: ModelSubscriptionSubscriberFilterInput
    $owner: String
  ) {
    onCreateSubscriber(filter: $filter, owner: $owner) {
      id
      owner
      name
      address
      numabo
      secteur
      phone1
      phone2
      instructions
      longitude
      latitude
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      colis {
        nextToken
        __typename
      }
      type
      nb
      unsubscribed
      createdAt
      updatedAt
      missionSubscribersId
      __typename
    }
  }
`;
export const onUpdateSubscriber = /* GraphQL */ `
  subscription OnUpdateSubscriber(
    $filter: ModelSubscriptionSubscriberFilterInput
    $owner: String
  ) {
    onUpdateSubscriber(filter: $filter, owner: $owner) {
      id
      owner
      name
      address
      numabo
      secteur
      phone1
      phone2
      instructions
      longitude
      latitude
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      colis {
        nextToken
        __typename
      }
      type
      nb
      unsubscribed
      createdAt
      updatedAt
      missionSubscribersId
      __typename
    }
  }
`;
export const onDeleteSubscriber = /* GraphQL */ `
  subscription OnDeleteSubscriber(
    $filter: ModelSubscriptionSubscriberFilterInput
    $owner: String
  ) {
    onDeleteSubscriber(filter: $filter, owner: $owner) {
      id
      owner
      name
      address
      numabo
      secteur
      phone1
      phone2
      instructions
      longitude
      latitude
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      colis {
        nextToken
        __typename
      }
      type
      nb
      unsubscribed
      createdAt
      updatedAt
      missionSubscribersId
      __typename
    }
  }
`;
export const onCreateMission = /* GraphQL */ `
  subscription OnCreateMission(
    $filter: ModelSubscriptionMissionFilterInput
    $owner: String
  ) {
    onCreateMission(filter: $filter, owner: $owner) {
      id
      owner
      name
      subscribers {
        nextToken
        __typename
      }
      livreurID
      inscriptions {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      daysOfWeek
      generateDayBefore
      startTime
      startTimeZone
      tournee {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const onUpdateMission = /* GraphQL */ `
  subscription OnUpdateMission(
    $filter: ModelSubscriptionMissionFilterInput
    $owner: String
  ) {
    onUpdateMission(filter: $filter, owner: $owner) {
      id
      owner
      name
      subscribers {
        nextToken
        __typename
      }
      livreurID
      inscriptions {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      daysOfWeek
      generateDayBefore
      startTime
      startTimeZone
      tournee {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const onDeleteMission = /* GraphQL */ `
  subscription OnDeleteMission(
    $filter: ModelSubscriptionMissionFilterInput
    $owner: String
  ) {
    onDeleteMission(filter: $filter, owner: $owner) {
      id
      owner
      name
      subscribers {
        nextToken
        __typename
      }
      livreurID
      inscriptions {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      daysOfWeek
      generateDayBefore
      startTime
      startTimeZone
      tournee {
        nextToken
        __typename
      }
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const onCreateInscription = /* GraphQL */ `
  subscription OnCreateInscription(
    $filter: ModelSubscriptionInscriptionFilterInput
    $owner: String
    $livreurID: String
  ) {
    onCreateInscription(filter: $filter, owner: $owner, livreurID: $livreurID) {
      id
      owner
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      livreurID
      createdAt
      updatedAt
      missionInscriptionsId
      __typename
    }
  }
`;
export const onUpdateInscription = /* GraphQL */ `
  subscription OnUpdateInscription(
    $filter: ModelSubscriptionInscriptionFilterInput
    $owner: String
    $livreurID: String
  ) {
    onUpdateInscription(filter: $filter, owner: $owner, livreurID: $livreurID) {
      id
      owner
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      livreurID
      createdAt
      updatedAt
      missionInscriptionsId
      __typename
    }
  }
`;
export const onDeleteInscription = /* GraphQL */ `
  subscription OnDeleteInscription(
    $filter: ModelSubscriptionInscriptionFilterInput
    $owner: String
    $livreurID: String
  ) {
    onDeleteInscription(filter: $filter, owner: $owner, livreurID: $livreurID) {
      id
      owner
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      livreurID
      createdAt
      updatedAt
      missionInscriptionsId
      __typename
    }
  }
`;
export const onCreateTournee = /* GraphQL */ `
  subscription OnCreateTournee(
    $filter: ModelSubscriptionTourneeFilterInput
    $owner: String
    $livreurID: String
  ) {
    onCreateTournee(filter: $filter, owner: $owner, livreurID: $livreurID) {
      id
      owner
      name
      status
      colis {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      livreurID
      missionTourneeId
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      createdAt
      distance
      duree
      nbColis
      updatedAt
      __typename
    }
  }
`;
export const onUpdateTournee = /* GraphQL */ `
  subscription OnUpdateTournee(
    $filter: ModelSubscriptionTourneeFilterInput
    $owner: String
    $livreurID: String
  ) {
    onUpdateTournee(filter: $filter, owner: $owner, livreurID: $livreurID) {
      id
      owner
      name
      status
      colis {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      livreurID
      missionTourneeId
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      createdAt
      distance
      duree
      nbColis
      updatedAt
      __typename
    }
  }
`;
export const onDeleteTournee = /* GraphQL */ `
  subscription OnDeleteTournee(
    $filter: ModelSubscriptionTourneeFilterInput
    $owner: String
    $livreurID: String
  ) {
    onDeleteTournee(filter: $filter, owner: $owner, livreurID: $livreurID) {
      id
      owner
      name
      status
      colis {
        nextToken
        __typename
      }
      startName
      startLongitude
      startLatitude
      livreurID
      missionTourneeId
      mission {
        id
        owner
        name
        livreurID
        startName
        startLongitude
        startLatitude
        daysOfWeek
        generateDayBefore
        startTime
        startTimeZone
        createdAt
        updatedAt
        __typename
      }
      createdAt
      distance
      duree
      nbColis
      updatedAt
      __typename
    }
  }
`;
export const onCreateColis = /* GraphQL */ `
  subscription OnCreateColis(
    $filter: ModelSubscriptionColisFilterInput
    $owner: String
  ) {
    onCreateColis(filter: $filter, owner: $owner) {
      id
      owner
      tournee {
        id
        owner
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        __typename
      }
      tourneeColisId
      subscriber {
        id
        owner
        name
        address
        numabo
        secteur
        phone1
        phone2
        instructions
        longitude
        latitude
        type
        nb
        unsubscribed
        createdAt
        updatedAt
        missionSubscribersId
        __typename
      }
      subscriberColisId
      createdAt
      position
      polyline
      distance
      duration
      address
      longitude
      latitude
      subscriberName
      lastStatus {
        id
        owner
        colisLogsId
        status
        message
        createdAt
        longitude
        latitude
        updatedAt
        __typename
      }
      logs {
        nextToken
        __typename
      }
      updatedAt
      colisLastStatusId
      __typename
    }
  }
`;
export const onUpdateColis = /* GraphQL */ `
  subscription OnUpdateColis(
    $filter: ModelSubscriptionColisFilterInput
    $owner: String
  ) {
    onUpdateColis(filter: $filter, owner: $owner) {
      id
      owner
      tournee {
        id
        owner
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        __typename
      }
      tourneeColisId
      subscriber {
        id
        owner
        name
        address
        numabo
        secteur
        phone1
        phone2
        instructions
        longitude
        latitude
        type
        nb
        unsubscribed
        createdAt
        updatedAt
        missionSubscribersId
        __typename
      }
      subscriberColisId
      createdAt
      position
      polyline
      distance
      duration
      address
      longitude
      latitude
      subscriberName
      lastStatus {
        id
        owner
        colisLogsId
        status
        message
        createdAt
        longitude
        latitude
        updatedAt
        __typename
      }
      logs {
        nextToken
        __typename
      }
      updatedAt
      colisLastStatusId
      __typename
    }
  }
`;
export const onDeleteColis = /* GraphQL */ `
  subscription OnDeleteColis(
    $filter: ModelSubscriptionColisFilterInput
    $owner: String
  ) {
    onDeleteColis(filter: $filter, owner: $owner) {
      id
      owner
      tournee {
        id
        owner
        name
        status
        startName
        startLongitude
        startLatitude
        livreurID
        missionTourneeId
        createdAt
        distance
        duree
        nbColis
        updatedAt
        __typename
      }
      tourneeColisId
      subscriber {
        id
        owner
        name
        address
        numabo
        secteur
        phone1
        phone2
        instructions
        longitude
        latitude
        type
        nb
        unsubscribed
        createdAt
        updatedAt
        missionSubscribersId
        __typename
      }
      subscriberColisId
      createdAt
      position
      polyline
      distance
      duration
      address
      longitude
      latitude
      subscriberName
      lastStatus {
        id
        owner
        colisLogsId
        status
        message
        createdAt
        longitude
        latitude
        updatedAt
        __typename
      }
      logs {
        nextToken
        __typename
      }
      updatedAt
      colisLastStatusId
      __typename
    }
  }
`;
export const onCreateColisStatus = /* GraphQL */ `
  subscription OnCreateColisStatus(
    $filter: ModelSubscriptionColisStatusFilterInput
    $owner: String
  ) {
    onCreateColisStatus(filter: $filter, owner: $owner) {
      id
      owner
      colis {
        id
        owner
        tourneeColisId
        subscriberColisId
        createdAt
        position
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        colisLastStatusId
        __typename
      }
      colisLogsId
      status
      message
      createdAt
      longitude
      latitude
      updatedAt
      __typename
    }
  }
`;
export const onUpdateColisStatus = /* GraphQL */ `
  subscription OnUpdateColisStatus(
    $filter: ModelSubscriptionColisStatusFilterInput
    $owner: String
  ) {
    onUpdateColisStatus(filter: $filter, owner: $owner) {
      id
      owner
      colis {
        id
        owner
        tourneeColisId
        subscriberColisId
        createdAt
        position
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        colisLastStatusId
        __typename
      }
      colisLogsId
      status
      message
      createdAt
      longitude
      latitude
      updatedAt
      __typename
    }
  }
`;
export const onDeleteColisStatus = /* GraphQL */ `
  subscription OnDeleteColisStatus(
    $filter: ModelSubscriptionColisStatusFilterInput
    $owner: String
  ) {
    onDeleteColisStatus(filter: $filter, owner: $owner) {
      id
      owner
      colis {
        id
        owner
        tourneeColisId
        subscriberColisId
        createdAt
        position
        polyline
        distance
        duration
        address
        longitude
        latitude
        subscriberName
        updatedAt
        colisLastStatusId
        __typename
      }
      colisLogsId
      status
      message
      createdAt
      longitude
      latitude
      updatedAt
      __typename
    }
  }
`;
export const onCreateLocation = /* GraphQL */ `
  subscription OnCreateLocation(
    $filter: ModelSubscriptionLocationFilterInput
    $owner: String
  ) {
    onCreateLocation(filter: $filter, owner: $owner) {
      id
      owner
      userId
      userName
      tourneeId
      latitude
      longitude
      lastUpdate
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const onUpdateLocation = /* GraphQL */ `
  subscription OnUpdateLocation(
    $filter: ModelSubscriptionLocationFilterInput
    $owner: String
  ) {
    onUpdateLocation(filter: $filter, owner: $owner) {
      id
      owner
      userId
      userName
      tourneeId
      latitude
      longitude
      lastUpdate
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const onDeleteLocation = /* GraphQL */ `
  subscription OnDeleteLocation(
    $filter: ModelSubscriptionLocationFilterInput
    $owner: String
  ) {
    onDeleteLocation(filter: $filter, owner: $owner) {
      id
      owner
      userId
      userName
      tourneeId
      latitude
      longitude
      lastUpdate
      createdAt
      updatedAt
      __typename
    }
  }
`;
