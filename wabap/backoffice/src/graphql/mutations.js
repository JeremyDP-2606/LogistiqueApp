/* eslint-disable */
// this is an auto generated file. This will be overwritten

export const createSubscriber = /* GraphQL */ `
  mutation CreateSubscriber(
    $input: CreateSubscriberInput!
    $condition: ModelSubscriberConditionInput
  ) {
    createSubscriber(input: $input, condition: $condition) {
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
export const updateSubscriber = /* GraphQL */ `
  mutation UpdateSubscriber(
    $input: UpdateSubscriberInput!
    $condition: ModelSubscriberConditionInput
  ) {
    updateSubscriber(input: $input, condition: $condition) {
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
export const deleteSubscriber = /* GraphQL */ `
  mutation DeleteSubscriber(
    $input: DeleteSubscriberInput!
    $condition: ModelSubscriberConditionInput
  ) {
    deleteSubscriber(input: $input, condition: $condition) {
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
export const createMission = /* GraphQL */ `
  mutation CreateMission(
    $input: CreateMissionInput!
    $condition: ModelMissionConditionInput
  ) {
    createMission(input: $input, condition: $condition) {
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
      deliveryChecking
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const updateMission = /* GraphQL */ `
  mutation UpdateMission(
    $input: UpdateMissionInput!
    $condition: ModelMissionConditionInput
  ) {
    updateMission(input: $input, condition: $condition) {
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
      deliveryChecking
      createdAt
      updatedAt
      __typename
    }
  }
`;
export const deleteMission = /* GraphQL */ `
  mutation DeleteMission(
    $input: DeleteMissionInput!
    $condition: ModelMissionConditionInput
  ) {
    deleteMission(input: $input, condition: $condition) {
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
export const createInscription = /* GraphQL */ `
  mutation CreateInscription(
    $input: CreateInscriptionInput!
    $condition: ModelInscriptionConditionInput
  ) {
    createInscription(input: $input, condition: $condition) {
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
export const updateInscription = /* GraphQL */ `
  mutation UpdateInscription(
    $input: UpdateInscriptionInput!
    $condition: ModelInscriptionConditionInput
  ) {
    updateInscription(input: $input, condition: $condition) {
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
export const deleteInscription = /* GraphQL */ `
  mutation DeleteInscription(
    $input: DeleteInscriptionInput!
    $condition: ModelInscriptionConditionInput
  ) {
    deleteInscription(input: $input, condition: $condition) {
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
export const createTournee = /* GraphQL */ `
  mutation CreateTournee(
    $input: CreateTourneeInput!
    $condition: ModelTourneeConditionInput
  ) {
    createTournee(input: $input, condition: $condition) {
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
export const updateTournee = /* GraphQL */ `
  mutation UpdateTournee(
    $input: UpdateTourneeInput!
    $condition: ModelTourneeConditionInput
  ) {
    updateTournee(input: $input, condition: $condition) {
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
export const deleteTournee = /* GraphQL */ `
  mutation DeleteTournee(
    $input: DeleteTourneeInput!
    $condition: ModelTourneeConditionInput
  ) {
    deleteTournee(input: $input, condition: $condition) {
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
export const createColis = /* GraphQL */ `
  mutation CreateColis(
    $input: CreateColisInput!
    $condition: ModelColisConditionInput
  ) {
    createColis(input: $input, condition: $condition) {
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
export const updateColis = /* GraphQL */ `
  mutation UpdateColis(
    $input: UpdateColisInput!
    $condition: ModelColisConditionInput
  ) {
    updateColis(input: $input, condition: $condition) {
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
export const deleteColis = /* GraphQL */ `
  mutation DeleteColis(
    $input: DeleteColisInput!
    $condition: ModelColisConditionInput
  ) {
    deleteColis(input: $input, condition: $condition) {
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
export const createColisStatus = /* GraphQL */ `
  mutation CreateColisStatus(
    $input: CreateColisStatusInput!
    $condition: ModelColisStatusConditionInput
  ) {
    createColisStatus(input: $input, condition: $condition) {
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
export const updateColisStatus = /* GraphQL */ `
  mutation UpdateColisStatus(
    $input: UpdateColisStatusInput!
    $condition: ModelColisStatusConditionInput
  ) {
    updateColisStatus(input: $input, condition: $condition) {
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
export const deleteColisStatus = /* GraphQL */ `
  mutation DeleteColisStatus(
    $input: DeleteColisStatusInput!
    $condition: ModelColisStatusConditionInput
  ) {
    deleteColisStatus(input: $input, condition: $condition) {
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
export const createLocation = /* GraphQL */ `
  mutation CreateLocation(
    $input: CreateLocationInput!
    $condition: ModelLocationConditionInput
  ) {
    createLocation(input: $input, condition: $condition) {
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
export const updateLocation = /* GraphQL */ `
  mutation UpdateLocation(
    $input: UpdateLocationInput!
    $condition: ModelLocationConditionInput
  ) {
    updateLocation(input: $input, condition: $condition) {
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
export const deleteLocation = /* GraphQL */ `
  mutation DeleteLocation(
    $input: DeleteLocationInput!
    $condition: ModelLocationConditionInput
  ) {
    deleteLocation(input: $input, condition: $condition) {
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
